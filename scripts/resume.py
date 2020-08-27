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


cfg = util.Config.load_config(Path(__file__).with_name('config.yaml'))

SCONTROL = Path(cfg.slurm_cmd_path or '')/'scontrol'
LOGFILE = (Path(cfg.log_dir or '')/Path(__file__).name).with_suffix('.log')

TOT_REQ_CNT = 1000

instances = {}
operations = {}
retry_list = []

util.config_root_logger(level='DEBUG', util_level='ERROR', file=LOGFILE)
log = logging.getLogger(Path(__file__).name)


if cfg.google_app_cred_path:
    os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = cfg.google_app_cred_path

credentials = compute_engine.Credentials()

http = None
authorized_http = None
if not cfg.google_app_cred_path:
    http = set_user_agent(httplib2.Http(), "Slurm_GCP_Scripts/1.1 (GPN:SchedMD)")
    authorized_http = google_auth_httplib2.AuthorizedHttp(credentials, http=http)


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
                project=cfg.project, zone=cfg.partitions[pid].zone,
                instance=node_name, fields=my_fields).execute()
            instance_ip = instance_networks['networkInterfaces'][0]['networkIP']

            util.run(
                f"{SCONTROL} update node={node_name} nodeaddr={instance_ip}")

            log.info("Instance " + node_name + " is now up")
        except Exception:
            log.exception(f"Error in adding {node_name} to slurm")
# [END update_slurm_node_addrs]


def create_instance(compute, zone, machine_type, instance_name,
                    source_disk_image):

    pid = util.get_pid(instance_name)
    # Configure the machine
    machine_type_path = f'zones/{zone}/machineTypes/{machine_type}'
    disk_type = 'projects/{}/zones/{}/diskTypes/{}'.format(
        cfg.project, zone, cfg.partitions[pid].compute_disk_type)

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
                'diskSizeGb': cfg.partitions[pid].compute_disk_size_gb
            }
        }],

        # Specify a network interface
        'networkInterfaces': [{
            'subnetwork': (
                "projects/{}/regions/{}/subnetworks/{}".format(
                    cfg.shared_vpc_host_project or cfg.project,
                    cfg.partitions[pid].region,
                    (cfg.partitions[pid].vpc_subnet
                     or f'{cfg.cluster_name}-{cfg.partitions[pid].region}'))
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
                 'value': 'GlobalOnly'}
            ]
        }
    }

    shutdown_script_path = Path('/apps/slurm/scripts/compute-shutdown')
    if shutdown_script_path.exists():
        config['metadata']['items'].append({
            'key': 'shutdown-script',
            'value': shutdown_script_path.read_text()
        })

    if cfg.partitions[pid].gpu_type:
        accel_type = ('https://www.googleapis.com/compute/v1/projects/{}/zones/{}/acceleratorTypes/{}'
                      .format(cfg.project, zone,
                              cfg.partitions[pid].gpu_type))
        config['guestAccelerators'] = [{
            'acceleratorCount': cfg.partitions[pid].gpu_count,
            'acceleratorType': accel_type
        }]

        config['scheduling'] = {'onHostMaintenance': 'TERMINATE'}

    if cfg.partitions[pid].preemptible_bursting:
        config['scheduling'] = {
            'preemptible': True,
            'onHostMaintenance': 'TERMINATE',
            'automaticRestart': False
        },

    if cfg.partitions[pid].compute_labels:
        config['labels'] = cfg.partitions[pid].compute_labels,

    if cfg.partitions[pid].cpu_platform:
        config['minCpuPlatform'] = cfg.partitions[pid].cpu_platform,

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


@util.static_vars(images={})
def get_source_image(compute, node_name):

    images = get_source_image.images
    pid = util.get_pid(node_name)
    if pid not in images:
        image_name = f"{cfg.compute_node_prefix}-{pid}-image"
        family = (cfg.partitions[pid].compute_image_family
                  or f"{image_name}-family")
        try:
            image_response = compute.images().getFromFamily(
                project=(cfg.partitions[pid].compute_image_family_project or
                         cfg.project),
                family=family
            ).execute()
            if image_response['status'] != 'READY':
                raise Exception("Image not ready")
            source_disk_image = image_response['selfLink']
        except Exception as e:
            log.error(f"Image {family} unavailable: {e}")
            sys.exit()

        images[pid] = source_disk_image
    return images[pid]
# [END get_source_image]


def add_instances(compute, node_list):

    batch_list = []
    curr_batch = 0
    req_cnt = 0
    batch_list.insert(
        curr_batch, compute.new_batch_http_request(callback=added_instances_cb))

    for node_name in node_list:

        if req_cnt >= TOT_REQ_CNT:
            req_cnt = 0
            curr_batch += 1
            batch_list.insert(
                curr_batch,
                compute.new_batch_http_request(callback=added_instances_cb))

        source_disk_image = get_source_image(compute, node_name)

        pid = util.get_pid(node_name)
        batch_list[curr_batch].add(
            create_instance(compute, cfg.partitions[pid].zone,
                            cfg.partitions[pid].machine_type, node_name,
                            source_disk_image),
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


def main(arg_nodes):
    log.info(f"Bursting out: {arg_nodes}")
    compute = googleapiclient.discovery.build('compute', 'v1',
                                              http=authorized_http,
                                              cache_discovery=False)

    # Get node list
    nodes_str = util.run(f"{SCONTROL} show hostnames {arg_nodes}",
                         check=True, get_stdout=True).stdout
    node_list = nodes_str.splitlines()

    while True:
        add_instances(compute, node_list)
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
    parser.add_argument('nodes', help='Nodes to burst')

    args = parser.parse_args()

    main(args.nodes)
