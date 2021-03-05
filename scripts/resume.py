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
import time
from pathlib import Path

import googleapiclient.discovery
from google.auth import compute_engine
import google_auth_httplib2
from googleapiclient.http import set_user_agent

import util

PLACEMENT_MAX_CNT = 22

cfg = util.Config.load_config(Path(__file__).with_name('config.yaml'))

SCONTROL = Path(cfg.slurm_cmd_path or '')/'scontrol'
LOGFILE = (Path(cfg.log_dir or '')/Path(__file__).name).with_suffix('.log')
SCRIPTS_DIR = Path(__file__).parent.resolve()

TOT_REQ_CNT = 1000

instances = {}
operations = {}
retry_list = []

if cfg.google_app_cred_path:
    os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = cfg.google_app_cred_path

credentials = compute_engine.Credentials()

http = None
authorized_http = None
if not cfg.google_app_cred_path:
    http = set_user_agent(httplib2.Http(),
                          "Slurm_GCP_Scripts/1.1 (GPN:SchedMD)")
    authorized_http = google_auth_httplib2.AuthorizedHttp(credentials,
                                                          http=http)


def wait_for_operation(compute, project, operation):
    print('Waiting for operation to finish...')
    while True:
        result = None
        if 'zone' in operation:
            result = compute.zoneOperations().get(
                project=project,
                zone=operation['zone'].split('/')[-1],
                operation=operation['name']).execute()
        elif 'region' in operation:
            result = compute.regionOperations().get(
                project=project,
                region=operation['region'].split('/')[-1],
                operation=operation['name']).execute()
        else:
            result = compute.globalOperations().get(
                project=project,
                operation=operation['name']).execute()

        if result['status'] == 'DONE':
            print("done.")
            if 'error' in result:
                raise Exception(result['error'])
            return result

        time.sleep(1)
# [END wait_for_operation]


def update_slurm_node_addrs(compute):
    for node_name, operation in operations.items():
        try:
            # Do this after the instances have been initialized and then wait
            # for all operations to finish. Then updates their addrs.
            wait_for_operation(compute, cfg.project, operation)

            pid = util.get_pid(node_name)
            my_fields = 'networkInterfaces(name,network,networkIP,subnetwork)'
            instance_networks = compute.instances().get(
                project=cfg.project, zone=cfg.instance_defs[pid].zone,
                instance=node_name, fields=my_fields).execute()
            instance_ip = instance_networks['networkInterfaces'][0]['networkIP']

            util.run(
                f"{SCONTROL} update node={node_name} nodeaddr={instance_ip}")

            log.info("Instance " + node_name + " is now up")
        except Exception:
            log.exception(f"Error in adding {node_name} to slurm")
# [END update_slurm_node_addrs]


def create_instance(compute, zone, machine_type, instance_name,
                    source_disk_image, placement_group_name):

    pid = util.get_pid(instance_name)
    # Configure the machine
    machine_type_path = f'zones/{zone}/machineTypes/{machine_type}'
    disk_type = 'projects/{}/zones/{}/diskTypes/{}'.format(
        cfg.project, zone, cfg.instance_defs[pid].compute_disk_type)

    meta_files = {
        'config': SCRIPTS_DIR/'config.yaml',
        'util-script': SCRIPTS_DIR/'util.py',
        'startup-script': SCRIPTS_DIR/'startup.sh',
        'setup-script': SCRIPTS_DIR/'setup.py',
    }
    custom_compute = SCRIPTS_DIR/'custom-compute-install'
    if custom_compute.exists():
        meta_files['custom-compute-install'] = str(custom_compute)

    config = {
        'name': instance_name,
        'machineType': machine_type_path,

        # Specify the boot disk and the image to use as a source.
        'disks': [{
            'boot': True,
            'autoDelete': True,
            'initializeParams': {
                'sourceImage': source_disk_image,
                'diskType': disk_type,
                'diskSizeGb': cfg.instance_defs[pid].compute_disk_size_gb
            }
        }],

        # Specify a network interface
        'networkInterfaces': [{
            'subnetwork': (
                "projects/{}/regions/{}/subnetworks/{}".format(
                    cfg.shared_vpc_host_project or cfg.project,
                    cfg.instance_defs[pid].region,
                    (cfg.instance_defs[pid].vpc_subnet
                     or f'{cfg.cluster_name}-{cfg.instance_defs[pid].region}'))
            ),
        }],

        # Allow the instance to access cloud storage and logging.
        'serviceAccounts': [{
            'email': cfg.compute_node_service_account,
            'scopes': cfg.compute_node_scopes
        }],

        'tags': {'items': ['compute']},

        'metadata': {
            'items': [
                {'key': 'enable-oslogin',
                 'value': 'TRUE'},
                {'key': 'VmDnsSetting',
                 'value': 'GlobalOnly'},
                {'key': 'terraform',
                 'value': 'TRUE'},
                *[{'key': k, 'value': Path(v).read_text()} for k, v in meta_files.items()]
            ]
        }
    }

    if placement_group_name is not None:
        config['scheduling'] = {
            'onHostMaintenance': 'TERMINATE',
            'automaticRestart': False
        },
        config['resourcePolicies'] = [
            'https://www.googleapis.com/compute/v1/projects/{}/regions/{}/resourcePolicies/{}'
            .format(cfg.shared_vpc_host_project or cfg.project,
                    cfg.instance_defs[pid].region, placement_group_name)
        ]

    if cfg.instance_defs[pid].gpu_type:
        accel_type = ('https://www.googleapis.com/compute/v1/projects/{}/zones/{}/acceleratorTypes/{}'
                      .format(cfg.project, zone,
                              cfg.instance_defs[pid].gpu_type))
        config['guestAccelerators'] = [{
            'acceleratorCount': cfg.instance_defs[pid].gpu_count,
            'acceleratorType': accel_type
        }]

        config['scheduling'] = {'onHostMaintenance': 'TERMINATE'}

    if cfg.instance_defs[pid].preemptible_bursting:
        config['scheduling'] = {
            'preemptible': True,
            'onHostMaintenance': 'TERMINATE',
            'automaticRestart': False
        },

    if cfg.instance_defs[pid].compute_labels:
        config['labels'] = cfg.instance_defs[pid].compute_labels,

    if cfg.instance_defs[pid].cpu_platform:
        config['minCpuPlatform'] = cfg.instance_defs[pid].cpu_platform,

    if cfg.external_compute_ips:
        config['networkInterfaces'][0]['accessConfigs'] = [
            {'type': 'ONE_TO_ONE_NAT', 'name': 'External NAT'}
        ]

    return compute.instances().insert(
        project=cfg.project,
        zone=zone,
        body=config)
# [END create_instance]


def added_instances_cb(request_id, response, exception):
    if exception is not None:
        log.error(f"add exception for node {request_id}: {exception}")
        if "Rate Limit Exceeded" in str(exception):
            retry_list.append(request_id)
    else:
        operations[request_id] = response
# [END added_instances_cb]


def add_instances(compute, node_list, arg_job_id, placement_groups):

    placement_group_name = None
    pg_index = 0
    batch_list = []
    curr_batch = 0
    req_cnt = 0
    batch_list.insert(
        curr_batch, compute.new_batch_http_request(callback=added_instances_cb))

    for i, node_name in enumerate(node_list):

        pid = util.get_pid(node_name)
        if (not arg_job_id and cfg.instance_defs[pid].exclusive):
            # Node was created by PrologSlurmctld, skip for ResumeProgram.
            continue

        if placement_groups:
            if i != 0 and i % PLACEMENT_MAX_CNT == 0:
                pg_index += 1
            placement_group_name = placement_groups[pg_index]

        if req_cnt >= TOT_REQ_CNT:
            req_cnt = 0
            curr_batch += 1
            batch_list.insert(
                curr_batch,
                compute.new_batch_http_request(callback=added_instances_cb))

        pid = util.get_pid(node_name)
        source_disk_image = cfg.instance_defs[pid].image
        batch_list[curr_batch].add(
            create_instance(compute, cfg.instance_defs[pid].zone,
                            cfg.instance_defs[pid].machine_type, node_name,
                            source_disk_image, placement_group_name),
            request_id=node_name)
        req_cnt += 1

    try:
        for i, batch in enumerate(batch_list):
            batch.execute(http=http)
            if i < (len(batch_list) - 1):
                time.sleep(30)
    except Exception:
        log.exception("error in add batch")

    if cfg.update_node_addrs:
        update_slurm_node_addrs(compute)

# [END add_instances]


def create_placement_groups(compute, arg_job_id, vm_count, region):
    log.debug(f"Creating PG: {arg_job_id} vm_count:{vm_count} region:{region}")

    pg_names = []
    pg_ops = []
    pg_index = 0

    for i in range(vm_count):
        if i % PLACEMENT_MAX_CNT:
            continue
        pg_index += 1
        pg_name = f'{cfg.cluster_name}-{arg_job_id}-{pg_index}'
        pg_names.append(pg_name)

        config = {
            'name': pg_name,
            'region': region,
            'groupPlacementPolicy': {
                "collocation": "COLLOCATED",
                "vmCount": min(vm_count - i, PLACEMENT_MAX_CNT)
             }
        }

        pg_ops.append(compute.resourcePolicies().insert(
            project=cfg.project,
            region=region,
            body=config).execute())

    for operation in pg_ops:
        wait_for_operation(compute, cfg.project, operation)

    return pg_names
# [END create_placement_groups]


def main(arg_nodes, arg_job_id):
    log.info(f"Bursting out: {arg_nodes} {arg_job_id}")
    compute = googleapiclient.discovery.build('compute', 'v1',
                                              http=authorized_http,
                                              cache_discovery=False)

    # Get node list
    nodes_str = util.run(f"{SCONTROL} show hostnames {arg_nodes}",
                         check=True, get_stdout=True).stdout
    node_list = nodes_str.splitlines()

    placement_groups = None
    pid = util.get_pid(node_list[0])
    if (arg_job_id and not cfg.instance_defs[pid].exclusive):
        # Don't create from calls by PrologSlurmctld
        return

    if (arg_job_id and
            cfg.instance_defs[pid].enable_placement and
            cfg.instance_defs[pid].machine_type.split('-')[0] == "c2" and
            len(node_list) > 1):
        log.debug(f"creating placement group for {arg_job_id}")
        placement_groups = create_placement_groups(
            compute, arg_job_id, len(node_list), cfg.instance_defs[pid].region)
        time.sleep(5)

    while True:
        add_instances(compute, node_list, arg_job_id, placement_groups)
        if not len(retry_list):
            break

        log.debug("got {} nodes to retry ({})"
                  .format(len(retry_list), ','.join(retry_list)))
        node_list = list(retry_list)
        del retry_list[:]

    log.debug("done adding instances")
# [END main]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('args', nargs='+', help="nodes [jobid]")
    parser.add_argument('--debug', '-d', dest='debug', action='store_true',
                        help='Enable debugging output')

    job_id = 0
    nodes = ""

    if "SLURM_JOB_NODELIST" in os.environ:
        args = parser.parse_args(sys.argv[1:] +
                                 [os.environ['SLURM_JOB_NODELIST'],
                                  os.environ['SLURM_JOB_ID']])
    else:
        args = parser.parse_args()

    nodes = args.args[0]
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

    new_yaml = Path(__file__).with_name('config.yaml.new')
    if (not cfg.instance_defs or cfg.partitions) and not new_yaml.exists():
        log.info(f"partition declarations in config.yaml have been converted to a new format and saved to {new_yaml}. Replace config.yaml as soon as possible.")
        cfg.save_config(new_yaml)

    main(nodes, job_id)
