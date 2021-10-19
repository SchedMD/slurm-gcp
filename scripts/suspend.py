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
import httplib2
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
from util import lkp, cfg, compute
from setup import resolve_network_storage


PREFIX = Path('/usr/local/bin')
SCONTROL = PREFIX/'scontrol'

cfg.log_dir = '/var/log/slurm'
LOGFILE = (Path(cfg.log_dir or '')/Path(__file__).name).with_suffix('.log')
SCRIPTS_DIR = Path(__file__).parent.resolve()

TOT_REQ_CNT = 1000

util.config_root_logger(level='DEBUG', util_level='DEBUG',
                        logfile=LOGFILE)
log = logging.getLogger(Path(__file__).name)

if cfg.google_app_cred_path:
    os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = cfg.google_app_cred_path


def truncate_iter(iterable, max_count):
    end = '...'
    _iter = iter(iterable)
    for i, el in enumerate(_iter, start=1):
        if i >= max_count:
            yield end
            break
        yield el


def delete_instance_op(instance, project=None):
    project = project or lkp.project
    return compute.instances().delete(
        project=project,
        zone=lkp.instance_zone(instance),
        instance=instance,
    )


def delete_instances(instances):
    """ Call regionInstances.bulkInsert to create instances """
    if len(instances) == 0:
        return
    ops = {
        inst: delete_instance_op(inst) for inst in instances
    }
    done, failed = batch_execute(ops)
    if failed:
        failed_nodes = [f"{n}: {e}" for n, (_, e) in failed.items()]
        node_str = '\n'.join(str(el) for el in truncate_iter(failed_nodes, 5))
        log.error(f"some nodes failed to delete: {node_str}")
    wait_for_operations(done)


def expand_nodelist(nodelist):
    """ expand nodes in hostlist to hostnames """
    nodes = run(f"{SCONTROL} show hostnames {nodelist}").stdout.splitlines()
    return nodes


def suspend_nodes(nodelist):
    """ resume nodes in nodelist """
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
        operations[request_id] = response
# [END delete_instances_cb]


def delete_instances(compute, node_list, arg_job_id):

    batch_list = []
    curr_batch = 0
    req_cnt = 0
    batch_list.insert(
        curr_batch,
        compute.new_batch_http_request(callback=delete_instances_cb))

    def_list = {pid: cfg.instance_defs[pid]
                for pid, nodes in groupby(node_list, util.get_pid)}
    regional_instances = util.get_regional_instances(compute, cfg.project,
                                                     def_list)

    for node_name in node_list:

        pid = util.get_pid(node_name)
        if (not arg_job_id and cfg.instance_defs[pid].exclusive):
            # Node was deleted by EpilogSlurmctld, skip for SuspendProgram
            continue

        zone = None
        if cfg.instance_defs[pid].regional_capacity:
            instance = regional_instances.get(node_name, None)
            if instance is None:
                log.debug("Regional node not found. Already deleted?")
                continue
            zone = instance['zone'].split('/')[-1]
        else:
            zone = cfg.instance_defs[pid].zone

        if req_cnt >= TOT_REQ_CNT:
            req_cnt = 0
            curr_batch += 1
            batch_list.insert(
                curr_batch,
                compute.new_batch_http_request(callback=delete_instances_cb))

        batch_list[curr_batch].add(
            compute.instances().delete(project=cfg.project,
                                       zone=zone,
                                       instance=node_name),
            request_id=node_name)
        req_cnt += 1

    try:
        for i, batch in enumerate(batch_list):
            util.ensure_execute(batch)
            if i < (len(batch_list) - 1):
                time.sleep(30)
    except Exception:
        log.exception("error in batch:")

# [END delete_instances]


def delete_placement_groups(compute, node_list, arg_job_id):
    PLACEMENT_MAX_CNT = 22
    pg_ops = []
    pg_index = 0
    pid = util.get_pid(node_list[0])

    for i in range(len(node_list)):
        if i % PLACEMENT_MAX_CNT:
            continue
        pg_index += 1
        pg_name = f'{cfg.cluster_name}-{arg_job_id}-{pg_index}'
        pg_ops.append(compute.resourcePolicies().delete(
            project=cfg.project, region=cfg.instance_defs[pid].region,
            resourcePolicy=pg_name).execute())
    for operation in pg_ops:
        util.wait_for_operation(compute, cfg.project, operation)
    log.debug("done deleting pg")
# [END delete_placement_groups]


def main(arg_nodes, arg_job_id):
    log.debug(f"deleting nodes:{arg_nodes} job_id:{job_id}")
    compute = googleapiclient.discovery.build('compute', 'v1',
                                              cache_discovery=False)

    # Get node list
    nodes_str = util.run(f"{SCONTROL} show hostnames {arg_nodes}").stdout
    node_list = nodes_str.splitlines()

    pid = util.get_pid(node_list[0])
    if (arg_job_id and not cfg.instance_defs[pid].exclusive):
        # Don't delete from calls by EpilogSlurmctld
        return
    # model here indicates any node that can be used to describe the rest
    model = next(iter(nodes))
    template = lkp.node_template_props(model).url
    partition_name = lkp.node_partition(model)
    partition = cfg.partitions[partition_name]

    body = NSDict()
    body.count = len(nodes)
    body.sourceInstanceTemplate = template
    body.perInstanceProperties = {k: {} for k in nodes}
    body.instanceProperties = instance_properties(partition_name)

    with lkp.sync_compute() as compute:
        result = util.ensure_execute(compute.regionInstances().bulkInsert(
            project=cfg.project, region=partition.region, body=body
        ))
    return result


def expand_nodelist(nodelist):
    """ expand nodes in hostlist to hostnames """
    nodes = run(f"{SCONTROL} show hostnames {nodelist}").stdout.splitlines()
    return nodes


def suspend_nodes(nodelist):
    """ resume nodes in nodelist """
    nodes = expand_nodelist(nodelist)


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

    if args.debug:
        util.config_root_logger(level='DEBUG', util_level='DEBUG',
                                logfile=LOGFILE)
    else:
        util.config_root_logger(level='INFO', util_level='ERROR',
                                logfile=LOGFILE)
    log = logging.getLogger(Path(__file__).name)
    sys.excepthook = util.handle_exception

    main(args.nodelist, args.job_id)
