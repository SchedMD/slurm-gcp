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
import shlex
import subprocess
import sys
import time
from pathlib import Path

import googleapiclient.discovery
from google.auth import compute_engine
import google_auth_httplib2
from googleapiclient.http import set_user_agent

import util


cfg = util.Config.load_config(Path(__file__).with_name('config.yaml'))

NETWORK_TYPE = 'subnetwork'
NETWORK      = ("projects/{}/regions/{}/subnetworks/{}-slurm-subnet".
                format(cfg.project, cfg.region, cfg.cluster_name))

SCONTROL     = '/apps/slurm/current/bin/scontrol'
LOGFILE      = '/var/log/slurm/resume.log'

TOT_REQ_CNT = 1000

# Set to True if the nodes aren't accessible by dns.
UPDATE_NODE_ADDRS = False

instances = {}
operations = {}
retry_list = []

credentials = compute_engine.Credentials()

http = set_user_agent(httplib2.Http(), "Slurm_GCP_Scripts/1.1 (GPN:SchedMD)")
authorized_http = google_auth_httplib2.AuthorizedHttp(credentials, http=http)


def wait_for_operation(compute, project, zone, operation):
    print('Waiting for operation to finish...')
    while True:
        result = compute.zoneOperations().get(
            project=project,
            zone=zone,
            operation=operation).execute()

        if result['status'] == 'DONE':
            print("done.")
            if 'error' in result:
                raise Exception(result['error'])
            return result

        time.sleep(1)
# [END wait_for_operation]


def update_slurm_node_addrs(compute):
    for node_name in operations:
        try:
            operation = operations[node_name]
            # Do this after the instances have been initialized and then wait
            # for all operations to finish. Then updates their addrs.
            wait_for_operation(compute, cfg.project, cfg.zone,
                               operation['name'])

            my_fields = 'networkInterfaces(name,network,networkIP,subnetwork)'
            instance_networks = compute.instances().get(
                project=cfg.project, zone=cfg.zone, instance=node_name,
                fields=my_fields).execute()
            instance_ip = instance_networks['networkInterfaces'][0]['networkIP']

            node_update_cmd = "{} update node={} nodeaddr={}".format(
                SCONTROL, node_name, instance_ip)
            subprocess.call(shlex.split(node_update_cmd))

            logging.info("Instance " + node_name + " is now up")
        except Exception as e:
            logging.exception("Error in adding {} to slurm ({})".format(
                node_name, str(e)))
# [END update_slurm_node_addrs]


def create_instance(compute, zone, machine_type, instance_name,
                    source_disk_image):

    pid = util.get_pid(instance_name)
    # Configure the machine
    machine_type_path = f'zones/{zone}/machineTypes/{machine_type}'
    disk_type = 'projects/{}/zones/{}/diskTypes/{}'.format(
        cfg.project, zone, cfg.partitions[pid]['compute_disk_type'])
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
                'diskSizeGb': cfg.partitions[pid]['compute_disk_size_gb']
            }
        }],

        # Specify a network interface
        'networkInterfaces': [{
            NETWORK_TYPE: NETWORK,
        }],

        # Allow the instance to access cloud storage and logging.
        'serviceAccounts': [{
            'email': cfg.compute_node_service_account,
            'scopes': cfg.compute_node_scopes
        }],

        'tags': {'items': ['compute']},

        'metadata': {
            'items': [{
                'key': 'enable-oslogin',
                'value': 'TRUE'
            }]
        }
    }

    shutdown_script = open(
        '/apps/slurm/scripts/compute-shutdown', 'r').read()
    config['metadata']['items'].append({
        'key': 'shutdown-script',
        'value': shutdown_script
    })

    if "gpu_type" in cfg.partitions[pid]:
        accel_type = ('https://www.googleapis.com/compute/v1/projects/{}/zones/{}/acceleratorTypes/{}'
                      .format(cfg.project, zone,
                              cfg.partitions[pid]['gpu_type']))
        config['guestAccelerators'] = [{
            'acceleratorCount': cfg.partitions[pid]['gpu_count'],
            'acceleratorType': accel_type
        }]

        config['scheduling'] = {'onHostMaintenance': 'TERMINATE'}

    if cfg.partitions[pid]['preemptible_bursting']:
        config['scheduling'] = {
            'preemptible': True,
            'onHostMaintenance': 'TERMINATE',
            'automaticRestart': False
        },

    if 'compute_labels' in cfg.partitions[pid]:
        config['labels'] = cfg.partitions[pid]['compute_labels'],

    if 'cpu_platform' in cfg.partitions[pid]:
        config['minCpuPlatform'] = cfg.partitions[pid]['cpu_platform'],

    if cfg.vpc_subnet:
        net_type = 'projects/{}/regions/{}/subnetworks/{}'.format(
            cfg.project, cfg.region, cfg.vpc_subnet)
        config['networkInterfaces'] = [{
            NETWORK_TYPE: net_type
        }]

    if cfg.shared_vpc_host_proj:
        net_type = 'projects/{}/regions/{}/subnetworks/{}'.format(
            cfg.shared_vpc_host_proj, cfg.region, cfg.vpc_subnet)
        config['networkInterfaces'] = [{
            NETWORK_TYPE: net_type
        }]

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
        logging.error("add exception for node {}: {}".format(request_id,
                                                             str(exception)))
        if "Rate Limit Exceeded" in str(exception):
            retry_list.append(request_id)
    else:
        operations[request_id] = response
# [END added_instances_cb]


def get_source_image(compute):

    try:
        image_response = compute.images().getFromFamily(
            project=cfg.project,
            family=cfg.cluster_name + '-compute-image-family'
        ).execute()
        if image_response['status'] != 'READY':
            logging.debug("image not ready, using the startup script")
            raise Exception("image not ready")
        source_disk_image = image_response['selfLink']
    except:
        logging.error("No image found.")
        sys.exit()

    return source_disk_image
# [END get_source_image]


def add_instances(compute, source_disk_image, node_list):

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

        pid = util.get_pid(node_name)
        batch_list[curr_batch].add(
            create_instance(compute, cfg.partitions[pid]['zone'],
                            cfg.partitions[pid]['machine_type'], node_name,
                            source_disk_image),
            request_id=node_name)
        req_cnt += 1

    try:
        for i, batch in enumerate(batch_list):
            batch.execute(http=http)
            if i < (len(batch_list) - 1):
                time.sleep(30)
    except Exception as e:
        logging.exception("error in add batch: " + str(e))

    if UPDATE_NODE_ADDRS:
        update_slurm_node_addrs(compute)

# [END add_instances]


def main(arg_nodes):
    logging.debug("Bursting out:" + arg_nodes)
    compute = googleapiclient.discovery.build('compute', 'v1',
                                              http=authorized_http,
                                              cache_discovery=False)

    # Get node list
    show_hostname_cmd = "{} show hostnames {}".format(SCONTROL, arg_nodes)
    nodes_str = subprocess.check_output(shlex.split(
        show_hostname_cmd)).decode()
    node_list = nodes_str.splitlines()

    source_disk_image = get_source_image(compute)

    while True:
        add_instances(compute, source_disk_image, node_list)
        if not len(retry_list):
            break

        logging.debug("got {} nodes to retry ({})".
                      format(len(retry_list), ','.join(retry_list)))
        node_list = list(retry_list)
        del retry_list[:]

    logging.debug("done adding instances")
# [END main]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('nodes', help='Nodes to burst')

    args = parser.parse_args()

    # silence module logging
    for logger in logging.Logger.manager.loggerDict:
        logging.getLogger(logger).setLevel(logging.WARNING)

    logging.basicConfig(
        filename=LOGFILE,
        format='%(asctime)s %(name)s %(levelname)s: %(message)s',
        level=logging.DEBUG)

    main(args.nodes)
