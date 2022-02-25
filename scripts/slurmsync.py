#!/usr/bin/env python3

# Copyright 2019 SchedMD LLC.
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
import os
import sys
from pathlib import Path
from collections import namedtuple

import util
from util import run, seperate, batch_execute, static_nodeset, to_hostlist
from util import lkp, cfg, compute, dirs
from suspend import delete_instances


filename = Path(__file__).name
LOGFILE = (Path(cfg.slurm_log_dir if cfg else ".") / filename).with_suffix(".log")

log = logging.getLogger(filename)

TOT_REQ_CNT = 1000


def start_instance_op(inst, project=None):
    project = project or lkp.project
    return compute.instances().start(
        project=project,
        zone=lkp.instance(inst).zone,
        instance=inst,
    )


def start_instances(node_list):
    log.info("{} instances to start ({})".format(len(node_list), ",".join(node_list)))

    invalid, valid = seperate(lambda inst: bool(lkp.instance), node_list)
    ops = {inst: start_instance_op(inst) for inst in valid}

    done, failed = batch_execute(ops)


# [END start_instances]


StateTuple = namedtuple("StateTuple", "base,flags")


def make_node_tuple(node_line):
    """turn node,state line to (node, StateTuple(state))"""
    # state flags include: CLOUD, COMPLETING, DRAIN, FAIL, POWERED_DOWN,
    #   POWERING_DOWN
    node, fullstate = node_line.split(",")
    state = fullstate.split("+")
    state_tuple = StateTuple(state[0], set(state[1:]))
    return (node, state_tuple)


def sync_slurm():
    cmd = (
        f"{lkp.scontrol} show nodes | "
        r"grep -oP '^NodeName=\K(\S+)|State=\K(\S+)' | "
        r"paste -sd',\n'"
    )
    node_lines = run(cmd, shell=True).stdout.rstrip().splitlines()
    slurm_nodes = {
        node: state
        for node, state in map(make_node_tuple, node_lines)
        if "CLOUD" in state.flags
    }

    gcp_instances = lkp.instances()
    static_set = set(static_nodeset())

    to_down = []
    to_idle = []
    to_start = []
    to_resume = []
    for node, state in slurm_nodes.items():
        inst = lkp.instance(node)
        info = lkp.node_template_info(node)

        if ("POWERED_DOWN" not in state.flags) and ("POWERING_DOWN" not in state.flags):
            # slurm nodes that aren't in power_save and are stopped in GCP:
            #   mark down in slurm
            #   start them in gcp
            if inst and (inst.status == "TERMINATED"):
                if not state.base.startswith("DOWN"):
                    to_down.append(node)
                if info.scheduling.preemptible:
                    to_start.append(node)

            # can't check if the node doesn't exist in GCP while the node
            # is booting because it might not have been created yet by the
            # resume script.
            # This should catch the completing states as well.
            if (
                inst is None
                and "#" not in state.base
                and not state.base.startswith("DOWN")
            ):
                to_down.append(node)

        elif inst is None:
            # find nodes that are down~ in slurm and don't exist in gcp:
            #   mark idle~
            if state.base.startswith("DOWN") and "POWERED_DOWN" in state.flags:
                to_idle.append(node)
            elif "POWERING_DOWN" in state.flags:
                to_idle.append(node)
            elif state.base.startswith("COMPLETING"):
                to_down.append(node)
            elif node in static_set:
                to_resume.append(node)

    if len(to_down):
        log.info(
            "{} stopped/deleted instances ({})".format(len(to_down), ",".join(to_down))
        )
        hostlist = to_hostlist(to_down)
        run(
            f"{lkp.scontrol} update nodename={hostlist} state=down "
            "reason='Instance stopped/deleted'"
        )

    if len(to_start):
        start_instances(to_start)

    if len(to_idle):
        log.info("{} instances to idle ({})".format(len(to_idle), ",".join(to_idle)))
        hostlist = to_hostlist(to_idle)
        run(f"{lkp.scontrol} update nodename={hostlist} state=resume")

    if len(to_resume):
        log.info(
            "{} instances to resume ({})".format(len(to_resume), ",".join(to_resume))
        )
        hostlist = to_hostlist(to_resume)
        # run(f"{lkp.scontrol} update nodename={hostlist} state=power_down_force")
        run(f"{lkp.scontrol} update nodename={hostlist} state=power_up")

    # orphans are powered down in slurm but still running in GCP. They must be
    # purged
    orphans = [
        name
        for name, inst in gcp_instances.items()
        if inst.role == "compute"
        and inst.status == "RUNNING"
        and (name not in slurm_nodes or "POWERED_DOWN" in slurm_nodes[name].flags)
    ]
    if len(orphans):
        hostlist = to_hostlist(orphans)
        log.info(f"found orphaned instances, deleting {hostlist}")
        delete_instances(orphans)


def main():
    try:
        sync_slurm()
    except Exception:
        log.exception("failed to sync instances")


# [END main]


if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--debug",
        "-d",
        dest="debug",
        action="store_true",
        help="Enable debugging output",
    )

    args = parser.parse_args()
    util.chown_slurm(LOGFILE, mode=0o600)
    if args.debug:
        util.config_root_logger(
            filename, level="DEBUG", util_level="DEBUG", logfile=LOGFILE
        )
    else:
        util.config_root_logger(
            filename, level="INFO", util_level="ERROR", logfile=LOGFILE
        )
    sys.excepthook = util.handle_exception

    # only run one instance at a time
    pid_file = (Path("/tmp") / Path(__file__).name).with_suffix(".pid")
    with pid_file.open("w") as fp:
        try:
            fcntl.lockf(fp, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except IOError:
            sys.exit(0)

    main()
