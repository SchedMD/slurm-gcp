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
import time
from itertools import groupby
from pathlib import Path

import googleapiclient.discovery

import util

cfg = util.Config.load_config(Path(__file__).with_name('config.yaml'))

SCONTROL = Path(cfg.slurm_cmd_path or '')/'scontrol'
LOGFILE = (Path(cfg.log_dir or '')/Path(__file__).name).with_suffix('.log')

TOT_REQ_CNT = 1000

operations = {}
retry_list = []

if cfg.google_app_cred_path:
    os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = cfg.google_app_cred_path


def delete_instances_cb(request_id, response, exception):
    if exception is not None:
        log.error(f"delete exception for node {request_id}: {exception}")
        if "Rate Limit Exceeded" in str(exception) or "Quota exceeded" in str(exception):
            retry_list.append(request_id)
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
    nodes_str = util.run(f"{SCONTROL} show hostnames {arg_nodes}",
                         check=True, get_stdout=True).stdout
    node_list = nodes_str.splitlines()

    # Get static node list
    exc_nodes_hostlist = util.run(
        f"{SCONTROL} show config | "
        "awk '/SuspendExcNodes.*=/{print $3}'", shell=True,
        get_stdout=True).stdout
    nodes_exc_str = util.run(f"{SCONTROL} show hostnames {exc_nodes_hostlist}",
                             check=True, get_stdout=True).stdout
    node_exc_list = sorted(nodes_exc_str.splitlines(), key=util.get_pid)

    # Generate new arg_nodes without static nodes
    dynamic_nodes = list((set(node_exc_list) ^ set(node_list)) & set(node_list))
    node_list = dynamic_nodes
    arg_nodes = util.to_hostlist(SCONTROL, dynamic_nodes)

    if len(node_list) == 0:
        log.debug(f"Static nodes removed from request. No nodes remain in request.")
        return

    pid = util.get_pid(node_list[0])
    if (arg_job_id and not cfg.instance_defs[pid].exclusive):
        # Don't delete from calls by EpilogSlurmctld
        return

    if arg_job_id:
        # Mark nodes as off limits to new jobs while powering down.
        # Note: If PrologSlurmctld fails with a non-zero exit code,
        # "powering_up" flag would get stuck on the node. In 20.11 and prior:
        # state=down followed by state=power_down could clear it. In 21.08,
        # state=power_down_force can clear it.
        util.run(
            f"{SCONTROL} update node={arg_nodes} state=power_down_force")

    while True:
        delete_instances(compute, node_list, arg_job_id)
        if not len(retry_list):
            break

        log.debug("got {} nodes to retry ({})"
                  .format(len(retry_list), ','.join(retry_list)))
        node_list = list(retry_list)
        del retry_list[:]

    if arg_job_id:
        for operation in operations.values():
            try:
                util.wait_for_operation(compute, cfg.project, operation)
            except Exception:
                log.exception(f"Error in deleting {operation['name']} to slurm")
        # now that the instances are gone, resume to put back in service
        util.run(f"{SCONTROL} update node={arg_nodes} state=resume")

    log.debug("done deleting instances")

    if (arg_job_id and
            cfg.instance_defs[pid].enable_placement and
            len(node_list) > 1):
        delete_placement_groups(compute, node_list, arg_job_id)

    log.info(f"done deleting nodes:{arg_nodes} job_id:{job_id}")

# [END main]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('args', nargs='+', help="nodes [jobid]")
    parser.add_argument('--debug', '-d', dest='debug', action='store_true',
                        help='Enable debugging output')

    if "SLURM_JOB_NODELIST" in os.environ:
        args = parser.parse_args(sys.argv[1:] +
                                 [os.environ['SLURM_JOB_NODELIST'],
                                  os.environ['SLURM_JOB_ID']])
    else:
        args = parser.parse_args()

    nodes = args.args[0]
    job_id = 0
    if len(args.args) > 1:
        job_id = args.args[1]

    if args.debug:
        util.config_root_logger(level='DEBUG', util_level='DEBUG',
                                logfile=LOGFILE)
    else:
        util.config_root_logger(level='INFO', util_level='ERROR',
                                logfile=LOGFILE)
    log = logging.getLogger(Path(__file__).name)
    sys.excepthook = util.handle_exception

    main(nodes, job_id)
