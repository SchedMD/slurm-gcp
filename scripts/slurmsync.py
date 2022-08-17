#!/usr/bin/env python3

# Copyright (C) SchedMD LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import fcntl
import logging
import sys
from enum import Enum
from itertools import chain
from pathlib import Path
import yaml

import util
from util import (
    execute_with_futures,
    run,
    separate,
    batch_execute,
    subscription_create,
    subscription_delete,
    to_hostlist,
    with_static,
)
from util import lkp, cfg, compute
from suspend import delete_instances


filename = Path(__file__).name
LOGFILE = (Path(cfg.slurm_log_dir if cfg else ".") / filename).with_suffix(".log")

log = logging.getLogger(filename)

TOT_REQ_CNT = 1000


NodeStatus = Enum(
    "NodeStatus",
    (
        "terminated",
        "preempted",
        "unbacked",
        "restore",
        "resume",
        "orphan",
        "unknown",
        "unchanged",
    ),
)


SubscriptionStatus = Enum(
    "SubscriptionStatus",
    (
        "deleted",
        "missing",
        "orphaned",
        "unbacked",
        "unchanged",
    ),
)


def start_instance_op(inst, project=None):
    project = project or lkp.project
    return compute.instances().start(
        project=project,
        zone=lkp.instance(inst).zone,
        instance=inst,
    )


def start_instances(node_list):
    log.info("{} instances to start ({})".format(len(node_list), ",".join(node_list)))

    invalid, valid = separate(lambda inst: bool(lkp.instance), node_list)
    ops = {inst: start_instance_op(inst) for inst in valid}

    done, failed = batch_execute(ops)


@with_static(static_nodeset=None)
def find_node_status(nodename):
    """Determine node/instance status that requires action"""
    if find_node_status.static_nodeset is None:
        find_node_status.static_nodeset = set(util.to_hostnames(lkp.static_nodelist()))
    state = lkp.slurm_node(nodename)
    inst = lkp.instance(nodename)
    info = lkp.node_template_info(nodename)
    if inst is None:
        if state.base == "DOWN" and "POWERED_DOWN" in state.flags:
            return NodeStatus.restore
        if "POWERING_DOWN" in state.flags:
            return NodeStatus.restore
        if "COMPLETING" in state.flags:
            return NodeStatus.unbacked
        if state.base != "DOWN" and not (
            set(("POWER_DOWN", "POWERING_UP", "POWERING_DOWN", "POWERED_DOWN"))
            & state.flags
        ):
            return NodeStatus.unbacked
        if nodename in find_node_status.static_nodeset:
            return NodeStatus.resume
    elif (
        "POWERED_DOWN" not in state.flags
        and "POWERING_DOWN" not in state.flags
        and inst.status == "TERMINATED"
    ):
        if info.scheduling.preemptible:
            return NodeStatus.preempted
        if not state.base.startswith("DOWN"):
            return NodeStatus.terminated
    elif (state is None or "POWERED_DOWN" in state.flags) and inst.status == "RUNNING":
        return NodeStatus.orphan
    elif state is None:
        # if state is None here, the instance exists but it's not in Slurm
        return NodeStatus.unknown

    return NodeStatus.unchanged


def do_node_update(status, nodes):
    """update node/instance based on node status"""
    if status == NodeStatus.unchanged:
        return
    count = len(nodes)
    hostlist = util.to_hostlist(nodes)

    def nodes_down():
        """down nodes"""
        log.info(
            f"{count} nodes set down due to node status '{status.name}' ({hostlist})"
        )
        run(
            f"{lkp.scontrol} update nodename={hostlist} state=down reason='Instance stopped/deleted'"
        )

    def nodes_restart():
        """start instances for nodes"""
        log.info(f"{count} instances restarted ({hostlist})")
        start_instances(nodes)

    def nodes_idle():
        """idle nodes"""
        log.info(f"{count} nodes to idle ({hostlist})")
        run(f"{lkp.scontrol} update nodename={hostlist} state=resume")

    def nodes_resume():
        """resume nodes via scontrol"""
        log.info(f"{count} instances to resume ({hostlist})")
        run(f"{lkp.scontrol} update nodename={hostlist} state=power_up")

    def nodes_delete():
        """delete instances for nodes"""
        log.info(f"{count} instances to delete ({hostlist})")
        delete_instances(nodes)

    def nodes_unknown():
        """Error status, nodes shouldn't get in this status"""
        log.error(f"{count} nodes have unexpected status: ({hostlist})")
        first = next(iter(nodes))
        state = lkp.slurm_node(first)
        state = "{}+{}".format(state.base, "+".join(state.flags))
        inst = lkp.instance(first)
        log.error(f"{first} state: {state}, instance status:{inst.status}")

    update = dict.get(
        {
            NodeStatus.terminated: nodes_down,
            NodeStatus.preempted: lambda: (nodes_down(), nodes_restart()),
            NodeStatus.unbacked: nodes_down,
            NodeStatus.resume: nodes_resume,
            NodeStatus.restore: nodes_idle,
            NodeStatus.orphan: nodes_delete,
            NodeStatus.unknown: nodes_unknown,
            NodeStatus.unchanged: lambda: None,
        },
        status,
    )
    update()


def sync_slurm():
    compute_instances = [
        name for name, inst in lkp.instances().items() if inst.role == "compute"
    ]
    slurm_nodes = list(lkp.slurm_nodes().keys())
    all_nodes = list(
        set(
            chain(
                compute_instances,
                slurm_nodes,
            )
        )
    )
    log.debug(
        f"reconciling {len(compute_instances)} ({len(all_nodes)-len(compute_instances)}) GCP instances and {len(slurm_nodes)} Slurm nodes ({len(all_nodes)-len(slurm_nodes)})."
    )
    node_statuses = {
        k: list(v) for k, v in util.groupby_unsorted(all_nodes, find_node_status)
    }
    if log.isEnabledFor(logging.DEBUG):
        status_nodelist = {
            status.name: to_hostlist(nodes) for status, nodes in node_statuses.items()
        }
        log.debug(f"node statuses: \n{yaml.safe_dump(status_nodelist).rstrip()}")

    for status, nodes in node_statuses.items():
        do_node_update(status, nodes)


@with_static(static_nodeset=None)
def find_subscription_status(nodename):
    """Determine status of given subscription"""
    if find_node_status.static_nodeset is None:
        find_node_status.static_nodeset = set(util.to_hostnames(lkp.static_nodelist()))
    state = lkp.slurm_node(nodename)
    inst = lkp.instance(nodename)
    subscription = lkp.subscription(nodename)
    info = lkp.node_template_info(nodename)

    if not info:
        # NOTE: Node is not managed by slurm-gcp, ignore node
        return SubscriptionStatus.unchanged
    elif not subscription:
        if nodename in find_node_status.static_nodeset:
            return SubscriptionStatus.missing
        elif (
            inst
            and state.base != "DOWN"
            and not (
                set(("POWER_DOWN", "POWERING_UP", "POWERING_DOWN", "POWERED_DOWN"))
                & state.flags
            )
        ):
            return SubscriptionStatus.deleted
    else:
        if state is None:
            return SubscriptionStatus.orphaned
        elif set(("POWERING_DOWN", "POWERED_DOWN")) & state.flags:
            return SubscriptionStatus.unbacked

    return SubscriptionStatus.unchanged


def do_subscription_update(status, subscriptions):
    """update node/instance based on node status"""
    if status == SubscriptionStatus.unchanged:
        return
    count = len(subscriptions)
    hostlist = util.to_hostlist(subscriptions)

    def subscriptions_create():
        """create subscriptions"""
        log.info("Creating {} subcriptions ({})".format(count, hostlist))
        execute_with_futures(subscription_create, subscriptions)

    def subscriptions_delete():
        """delete subscriptions"""
        log.info("Deleting {} subcriptions ({})".format(count, hostlist))
        execute_with_futures(subscription_delete, subscriptions)

    update = dict.get(
        {
            SubscriptionStatus.deleted: subscriptions_create,
            SubscriptionStatus.missing: subscriptions_create,
            SubscriptionStatus.orphaned: subscriptions_delete,
            SubscriptionStatus.unbacked: subscriptions_delete,
            SubscriptionStatus.unchanged: lambda x: None,
        },
        status,
    )
    update()


def sync_pubsub():
    all_nodes = list(
        set(
            chain(
                (
                    name
                    for name, inst in lkp.instances().items()
                    if inst.role == "compute"
                ),
                (name for name in lkp.slurm_nodes().keys()),
            )
        )
    )
    subscriptions_statuses = {
        k: list(v)
        for k, v in util.groupby_unsorted(all_nodes, find_subscription_status)
    }

    for status, subscriptions in subscriptions_statuses.items():
        do_subscription_update(status, subscriptions)


def main():
    try:
        sync_slurm()
        if lkp.cfg.enable_reconfigure:
            sync_pubsub()
    except Exception:
        log.exception("failed to sync instances")


parser = argparse.ArgumentParser(
    description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
)
parser.add_argument(
    "--debug",
    "-d",
    dest="loglevel",
    action="store_const",
    const=logging.DEBUG,
    default=logging.INFO,
    help="Enable debugging output",
)
parser.add_argument(
    "--trace-api",
    "-t",
    action="store_true",
    help="Enable detailed api request output",
)

if __name__ == "__main__":

    args = parser.parse_args()
    util.chown_slurm(LOGFILE, mode=0o600)

    if cfg.enable_debug_logging:
        args.loglevel = logging.DEBUG
    if args.trace_api:
        cfg.extra_logging_flags = list(cfg.extra_logging_flags)
        cfg.extra_logging_flags.append("trace_api")
    util.config_root_logger(filename, level=args.loglevel, logfile=LOGFILE)

    sys.excepthook = util.handle_exception

    # only run one instance at a time
    pid_file = (Path("/tmp") / Path(__file__).name).with_suffix(".pid")
    with pid_file.open("w") as fp:
        try:
            fcntl.lockf(fp, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except IOError:
            sys.exit(0)

    main()
