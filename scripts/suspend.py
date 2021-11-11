#!/usr/bin/env python3

# Copyright 2017 SchedMD LLC.
# Modified for use with the Slurm Resource Manager.
#
# Copyright 2015 Google Inc. All rights reserved.
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
import logging
import os
import sys
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from functools import partial
from itertools import groupby, chain, islice

from addict import Dict as NSDict

import util
from util import run, batch_execute, ensure_execute, wait_for_operations
from util import partition
from util import lkp, cfg, compute


SCONTROL = Path(cfg.slurm_cmd_path or '')/'scontrol'

filename = Path(__file__).name
log = logging.getLogger(filename)

TOT_REQ_CNT = 1000


def truncate_iter(iterable, max_count):
    end = '...'
    _iter = iter(iterable)
    for i, el in enumerate(_iter, start=1):
        if i >= max_count:
            yield end
            break
        yield el


def delete_instance_op(instance, project=None, zone=None):
    project = project or lkp.project
    return compute.instances().delete(
        project=project,
        zone=(zone or lkp.instance(instance).zone),
        instance=instance,
    )


def delete_instances(instances):
    """ Call regionInstances.bulkInsert to create instances """
    if len(instances) == 0:
        return
    invalid, valid = partition(
        lambda inst: bool(lkp.instance(inst)),
        instances
    )
    log.debug("instances do not exist: {}".format(','.join(invalid)))

    ops = {inst: delete_instance_op(inst) for inst in valid}
    done, failed = batch_execute(ops)
    if failed:
        failed_nodes = [f"{n}: {e}" for n, (_, e) in failed.items()]
        node_str = '\n'.join(str(el) for el in truncate_iter(failed_nodes, 5))
        log.error(f"some nodes failed to delete: {node_str}")
    wait_for_operations(done.values())


def expand_nodelist(nodelist):
    """ expand nodes in hostlist to hostnames """
    nodes = run(f"{SCONTROL} show hostnames {nodelist}").stdout.splitlines()
    return nodes


def suspend_nodes(nodelist):
    """suspend nodes in nodelist """
    log.info(f"suspend {nodelist}")
    nodes = expand_nodelist(nodelist)
    delete_instances(nodes)


def epilog_suspend_nodes(nodelist, job_id):
    nodes = expand_nodelist(nodelist)
    model = next(iter(nodes))
    partition_name = lkp.node_partition(model)
    partition = cfg.partitions[partition_name]
    if not partition.exclusive:
        return
    # Mark nodes as off limits to new jobs while powering down.
    # Have to use "down" because it's the only, current, way to remove the
    # power_up flag from the node -- followed by a power_down -- if the
    # PrologSlurmctld fails with a non-zero exit code.
    run(f"{SCONTROL} update node={nodelist} state=down reason='{job_id} finishing'")
    # Power down nodes in slurm, so that they will become available again.
    run(f"{SCONTROL} update node={nodelist} state=power_down")

    delete_instances()


def main(nodelist, job_id):
    """ main called when run as script """
    log.debug(f"main {nodelist} {job_id}")
    if job_id is not None:
        epilog_suspend_nodes(nodelist, job_id)
    else:
        suspend_nodes(nodelist)


parser = argparse.ArgumentParser(
    description=__doc__,
    formatter_class=argparse.RawDescriptionHelpFormatter)
parser.add_argument(
    'nodelist', help="list of nodes to suspend"
)
parser.add_argument(
    'job_id', nargs='?', default=None,
    help="Optional job id for node list. Implies that PrologSlurmctld called program"
)
parser.add_argument('--debug', '-d', dest='debug', action='store_true',
                    help='Enable debugging output')


if __name__ == '__main__':
    if "SLURM_JOB_NODELIST" in os.environ:
        argv = [
            *sys.argv[1:],
            os.environ['SLURM_JOB_NODELIST'],
            os.environ['SLURM_JOB_ID'],
        ]
        args = parser.parse_args(argv)
    else:
        args = parser.parse_args()


    logfile = (Path(cfg.log_dir)/filename).with_suffix('.log')
    if args.debug:
        util.config_root_logger(filename, level='DEBUG', util_level='DEBUG',
                                logfile=logfile)
    else:
        util.config_root_logger(filename, level='INFO', util_level='ERROR',
                                logfile=logfile)
    log = logging.getLogger(Path(__file__).name)
    sys.excepthook = util.handle_exception

    main(args.nodelist, args.job_id)
