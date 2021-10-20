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
import collections
import fcntl
import logging
import os
import sys
import tempfile
from pathlib import Path
from time import sleep

import util
from util import partition, batch_execute
from util import lkp, cfg, compute


SCONTROL = Path(cfg.slurm_cmd_path or '')/'scontrol'
LOGFILE = (Path(cfg.log_dir or '')/Path(__file__).name).with_suffix('.log')
SCRIPTS_DIR = Path(__file__).parent.resolve()

logger_name = Path(__file__).name
log = logging.getLogger(logger_name)

TOT_REQ_CNT = 1000

retry_list = []


def start_instances_cb(request_id, response, exception):
    if exception is not None:
        log.error("start exception: " + str(exception))
        if "Rate Limit Exceeded" in str(exception):
            retry_list.append(request_id)
        elif "was not found" in str(exception):
            util.spawn(f"{SCRIPTS_DIR}/resume.py {request_id}")
# [END start_instances_cb]


def start_instance_op(inst, project=None):
    project = project or lkp.project
    return compute.instances().start(
        project=project,
        zone=lkp.instance(inst).zone,
        instance=inst,
    )


def start_instances(node_list):

    invalid, valid = partition(lambda inst: bool(lkp.instance), node_list)
    ops = {inst: start_instance_op(inst) for inst in valid}

    done, failed = batch_execute(ops)
# [END start_instances]


def main():
    try:
        s_nodes = dict()
        cmd = (f"{SCONTROL} show nodes | "
               r"grep -oP '^NodeName=\K(\S+)|State=\K(\S+)' | "
               "paste -sd',\n'")
        nodes = util.run(cmd, shell=True).stdout
        if nodes:
            # result is a list of tuples like:
            # (nodename, (base='base_state', flags=<set of state flags>))
            # from 'nodename,base_state+flag1+flag2'
            # state flags include: CLOUD, COMPLETING, DRAIN, FAIL, POWERED_DOWN,
            #   POWERING_DOWN
            # Modifiers on base state still include: @ (reboot), $ (maint),
            #   * (nonresponsive), # (powering up)
            StateTuple = collections.namedtuple('StateTuple', 'base,flags')

            def make_state_tuple(state):
                return StateTuple(state[0], set(state[1:]))
            s_nodes = [(node, make_state_tuple(args.split('+')))
                       for node, args in
                       map(lambda x: x.split(','), nodes.rstrip().splitlines())
                       if 'CLOUD' in args]

        to_down = []
        to_idle = []
        to_start = []
        for s_node, s_state in s_nodes:
            g_node = lkp.instance(s_node)
            pid = util.get_pid(s_node)

            if (('POWERED_DOWN' not in s_state.flags) and
                    ('POWERING_DOWN' not in s_state.flags)):
                # slurm nodes that aren't in power_save and are stopped in GCP:
                #   mark down in slurm
                #   start them in gcp
                if g_node and (g_node['status'] == "TERMINATED"):
                    if not s_state.base.startswith('DOWN'):
                        to_down.append(s_node)
                    if (cfg.instance_defs[pid].preemptible_bursting):
                        to_start.append(s_node)

                # can't check if the node doesn't exist in GCP while the node
                # is booting because it might not have been created yet by the
                # resume script.
                # This should catch the completing states as well.
                if (g_node is None and "#" not in s_state.base and
                        not s_state.base.startswith('DOWN')):
                    to_down.append(s_node)

            elif g_node is None:
                # find nodes that are down~ in slurm and don't exist in gcp:
                #   mark idle~
                if s_state.base.startswith('DOWN') and 'POWERED_DOWN' in s_state.flags:
                    to_idle.append(s_node)
                elif 'POWERING_DOWN' in s_state.flags:
                    to_idle.append(s_node)
                elif s_state.base.startswith('COMPLETING'):
                    to_down.append(s_node)

        if len(to_down):
            log.info("{} stopped/deleted instances ({})".format(
                len(to_down), ",".join(to_down)))
            log.info("{} instances to start ({})".format(
                len(to_start), ",".join(to_start)))

            # write hosts to a file that can be given to get a slurm
            # hostlist. Since the number of hosts could be large.
            tmp_file = tempfile.NamedTemporaryFile(mode='w+t', delete=False)
            tmp_file.writelines("\n".join(to_down))
            tmp_file.close()
            log.debug("tmp_file = {}".format(tmp_file.name))

            hostlist = util.run(
                f"{SCONTROL} show hostlist {tmp_file.name}").stdout.rstrip()
            log.debug("hostlist = {}".format(hostlist))
            os.remove(tmp_file.name)

            util.run(f"{SCONTROL} update nodename={hostlist} state=down "
                     "reason='Instance stopped/deleted'")

            while True:
                start_instances(to_start)
                if not len(retry_list):
                    break

                log.debug("got {} nodes to retry ({})"
                          .format(len(retry_list), ','.join(retry_list)))
                to_start = list(retry_list)
                del retry_list[:]

        if len(to_idle):
            log.info("{} instances to resume ({})".format(
                len(to_idle), ','.join(to_idle)))

            # write hosts to a file that can be given to get a slurm
            # hostlist. Since the number of hosts could be large.
            tmp_file = tempfile.NamedTemporaryFile(mode='w+t', delete=False)
            tmp_file.writelines("\n".join(to_idle))
            tmp_file.close()
            log.debug("tmp_file = {}".format(tmp_file.name))

            hostlist = util.run(f"{SCONTROL} show hostlist {tmp_file.name}").stdout.rstrip()
            log.debug("hostlist = {}".format(hostlist))
            os.remove(tmp_file.name)

            util.run(f"{SCONTROL} update nodename={hostlist} state=resume")

    except Exception:
        log.exception("failed to sync instances")

# [END main]


if __name__ == '__main__':

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--debug', '-d', dest='debug', action='store_true',
                        help='Enable debugging output')

    args = parser.parse_args()
    if args.debug:
        util.config_root_logger(logger_name, level='DEBUG', util_level='DEBUG',
                                logfile=LOGFILE)
    else:
        util.config_root_logger(logger_name, level='INFO', util_level='ERROR',
                                logfile=LOGFILE)
    sys.excepthook = util.handle_exception

    # only run one instance at a time
    pid_file = (Path('/tmp')/Path(__file__).name).with_suffix('.pid')
    with pid_file.open('w') as fp:
        try:
            fcntl.lockf(fp, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except IOError:
            sys.exit(0)

    main()
