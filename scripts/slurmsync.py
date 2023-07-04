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
import hashlib
import json
import logging
import re
import sys
from enum import Enum
from itertools import chain
from pathlib import Path
import yaml

import util
from util import (
    batch_execute,
    ensure_execute,
    fetch_config_yaml,
    load_config_file,
    run,
    save_config,
    separate,
    to_hostlist,
    with_static,
    Lookup,
    NSDict,
)
from util import lkp, cfg, compute, CONFIG_FILE
from suspend import delete_instances
from conf import (
    gen_cloud_conf,
    gen_cloud_gres_conf,
    install_slurm_conf,
    install_slurmdbd_conf,
    install_gres_conf,
    install_cgroup_conf,
)

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
        state is not None
        and "POWERED_DOWN" not in state.flags
        and "POWERING_DOWN" not in state.flags
        and inst.status == "TERMINATED"
    ):
        if inst.scheduling.preemptible:
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


def delete_placement_groups(placement_groups):
    def delete_placement_request(pg_name, region):
        return compute.resourcePolicies().delete(
            project=lkp.project, region=region, resourcePolicy=pg_name
        )

    requests = {
        pg.name: delete_placement_request(pg["name"], pg["region"])
        for pg in placement_groups
    }
    done, failed = batch_execute(requests)
    if failed:
        failed_pg = [f"{n}: {e}" for n, (_, e) in failed.items()]
        log.error(f"some placement groups failed to delete: {failed_pg}")
    log.info(f"deleted {len(done)} placement groups ({to_hostlist(done.keys())})")


def sync_placement_groups():
    """Delete placement policies that are for jobs that have completed/terminated"""
    keep_states = frozenset(
        [
            "RUNNING",
            "CONFIGURING",
            "STOPPED",
            "SUSPENDED",
            "COMPLETING",
        ]
    )
    keep_jobs = {
        job["job_id"]
        for job in json.loads(run(f"{lkp.scontrol} show jobs --json").stdout)["jobs"]
        if job["job_state"] in keep_states
    }

    fields = "items.regions.resourcePolicies,nextPageToken"
    flt = f"name={lkp.slurm_cluster_name}-*"
    act = compute.resourcePolicies()
    op = act.aggregatedList(project=lkp.project, fields=fields, filter=flt)
    placement_groups = {}
    pg_regex = re.compile(
        rf"{lkp.slurm_cluster_name}-(?<partition>[^\s\-]+)-(?P<job_id>\d+)-(?P<index>\d+)"
    )
    while op is not None:
        result = ensure_execute(op)
        # merge placement group info from API and job_id,partition,index parsed from the name
        placement_groups.update(
            {
                pg["name"]: NSDict({**pg, **pg_regex.match(pg["name"]).groupdict()})
                for pg in chain.from_iterable(
                    item["resourcePolicies"]
                    for item in result.get("items", {}).values()
                )
                if pg_regex.match(pg["name"]) is not None
                and pg["job_id"] not in keep_jobs
            }
        )
        op = act.aggregatedList_next(op, result)

    delete_placement_groups(list(placement_groups.values()))


def sync_slurm():
    if lkp.instance_role_safe != "controller":
        return

    compute_instances = [
        name for name, inst in lkp.instances().items() if inst.role == "compute"
    ]
    slurm_nodes = list(
        name
        for name, state in lkp.slurm_nodes().items()
        if "DYNAMIC_NORM" not in state.flags
    )
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


def reconfigure_slurm():
    CONFIG_FILE_TMP = Path("/tmp/config.yaml")

    cfg_old = load_config_file(CONFIG_FILE)
    hash_old = hashlib.sha256(yaml.dump(cfg_old, encoding="utf-8"))

    if cfg_old.hybrid:
        # terraform handles generating the config.yaml, don't do it here
        return

    cfg_new = fetch_config_yaml()
    # Save to file and read file to ensure Paths are marshalled the same
    save_config(cfg_new, CONFIG_FILE_TMP)
    cfg_new = load_config_file(CONFIG_FILE_TMP)
    hash_new = hashlib.sha256(yaml.dump(cfg_new, encoding="utf-8"))

    if hash_new.hexdigest() != hash_old.hexdigest():
        log.debug("Delta detected. Reconfiguring Slurm now.")
        save_config(cfg_new, CONFIG_FILE)
        lkp = Lookup(cfg_new)
        util.lkp = lkp
        if lkp.instance_role_safe == "controller":
            install_slurm_conf(lkp)
            install_slurmdbd_conf(lkp)
            gen_cloud_conf(lkp)
            gen_cloud_gres_conf(lkp)
            install_gres_conf(lkp)
            install_cgroup_conf(lkp)
            log.info("Restarting slurmctld to make changes take effect.")
            try:
                run("sudo systemctl restart slurmctld.service", check=False)
                run(f"{lkp.scontrol} reconfigure", timeout=30)
            except Exception as e:
                log.error(e)
            util.run("wall '*** slurm configuration been updated ***'", timeout=30)
            log.debug("Done.")
        elif lkp.instance_role_safe in ["compute", "login"]:
            log.info("Restarting slurmd to make changes take effect.")
            run("systemctl restart slurmd")
            util.run("wall '*** slurm configuration been updated ***'", timeout=30)
            log.debug("Done.")


def main():
    try:
        reconfigure_slurm()
    except Exception:
        log.exception("failed to reconfigure slurm")

    try:
        sync_slurm()
    except Exception:
        log.exception("failed to sync instances")

    try:
        sync_placement_groups()
    except Exception:
        log.exception("failed to sync placement groups")


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
parser.add_argument(
    "--force",
    "-f",
    action="store_true",
    help="Force tasks to run, regardless of lock.",
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
            if not args.force:
                sys.exit(0)

    main()
