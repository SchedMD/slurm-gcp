#!/usr/bin/python

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
import time

import googleapiclient.discovery
from google.auth import compute_engine
import google_auth_httplib2
from googleapiclient.http import set_user_agent

CLUSTER_NAME = '@CLUSTER_NAME@'

PROJECT      = '@PROJECT@'
ZONE         = '@ZONE@'
REGION       = '@REGION@'
MACHINE_TYPE = '@MACHINE_TYPE@'
CPU_PLATFORM = '@CPU_PLATFORM@'
PREEMPTIBLE  = @PREEMPTIBLE@
EXTERNAL_IP  = @EXTERNAL_COMPUTE_IPS@
SHARED_VPC_HOST_PROJ = '@SHARED_VPC_HOST_PROJ@'
VPC_SUBNET   = '@VPC_SUBNET@'

DISK_SIZE_GB = '@DISK_SIZE_GB@'
DISK_TYPE    = '@DISK_TYPE@'

LABELS       = @LABELS@

NETWORK_TYPE = 'subnetwork'
NETWORK      = "projects/{}/regions/{}/subnetworks/{}-slurm-subnet".format(PROJECT, REGION, CLUSTER_NAME)

GPU_TYPE     = '@GPU_TYPE@'
GPU_COUNT    = '@GPU_COUNT@'

SCONTROL     = '/apps/slurm/current/bin/scontrol'
LOGFILE      = '/apps/slurm/log/resume.log'

TOT_REQ_CNT = 1000

instances = {}
operations = {}
retry_list = []

credentials = compute_engine.Credentials()

http = set_user_agent(httplib2.Http(), "Slurm_GCP_Scripts/1.1 (GPN:SchedMD)")
authorized_http = google_auth_httplib2.AuthorizedHttp(credentials, http=http)

# [START create_instance]
def create_instance(compute, project, zone, instance_type, instance_name,
                    source_disk_image, have_compute_img):
    # Configure the machine
    machine_type = "zones/{}/machineTypes/{}".format(zone, instance_type)
    disk_type = "projects/{}/zones/{}/diskTypes/{}".format(PROJECT, ZONE,
                                                           DISK_TYPE)
    config = {
        'name': instance_name,
        'machineType': machine_type,

        # Specify the boot disk and the image to use as a source.
        'disks': [{
            'boot': True,
            'autoDelete': True,
            'initializeParams': {
                'sourceImage': source_disk_image,
                'diskType': disk_type,
                'diskSizeGb': DISK_SIZE_GB
            }
        }],

        # Specify a network interface
        'networkInterfaces': [{
            NETWORK_TYPE : NETWORK,
        }],

        # Allow the instance to access cloud storage and logging.
        'serviceAccounts': [{
            'email': 'default',
            'scopes': [
                'https://www.googleapis.com/auth/cloud-platform'
            ]
        }],

        'tags': {'items': ['compute'] },

        'metadata': {
            'items': [{
                'key': 'enable-oslogin',
                'value': 'TRUE'
            }]
        }
    }

    if not have_compute_img:
        startup_script = open(
            '/apps/slurm/scripts/startup-script.py', 'r').read()
        config['metadata']['items'].append({
            'key': 'startup-script',
            'value': startup_script
        })

    if GPU_TYPE:
        accel_type = ("https://www.googleapis.com/compute/v1/"
                      "projects/{}/zones/{}/acceleratorTypes/{}".format(
                          PROJECT, ZONE, GPU_TYPE))
        config['guestAccelerators'] = [{
            'acceleratorCount': GPU_COUNT,
            'acceleratorType' : accel_type
        }]

        config['scheduling'] = {'onHostMaintenance': 'TERMINATE'}

    if PREEMPTIBLE:
        config['scheduling'] = {
            "preemptible": True,
            "onHostMaintenance": "TERMINATE",
            "automaticRestart": False
        },

    if LABELS:
        config['labels'] = LABELS,

    if CPU_PLATFORM:
        config['minCpuPlatform'] = CPU_PLATFORM,

    if VPC_SUBNET:
        net_type = "projects/{}/regions/{}/subnetworks/{}".format(
            PROJECT, REGION, VPC_SUBNET)
        config['networkInterfaces'] = [{
            NETWORK_TYPE : net_type
        }]

    if SHARED_VPC_HOST_PROJ:
        net_type = "projects/{}/regions/{}/subnetworks/{}".format(
            SHARED_VPC_HOST_PROJ, REGION, VPC_SUBNET)
        config['networkInterfaces'] = [{
            NETWORK_TYPE : net_type
        }]

    if EXTERNAL_IP:
        config['networkInterfaces'][0]['accessConfigs'] = [
            {'type': 'ONE_TO_ONE_NAT', 'name': 'External NAT'}
        ]

    return compute.instances().insert(
        project=project,
        zone=zone,
        body=config)
# [END create_instance]

# [START added_instances_cb]
def added_instances_cb(request_id, response, exception):
    if exception is not None:
        logging.error("add exception for node {}: {}".format(request_id,
                                                             str(exception)))
        if "Rate Limit Exceeded" in str(exception):
            retry_list.append(request_id)
    else:
        operations[request_id] = response
# [END added_instances_cb]

# [start add_instances]
def add_instances(compute, source_disk_image, have_compute_img, node_list):

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

        batch_list[curr_batch].add(
            create_instance(
                compute, PROJECT, ZONE, MACHINE_TYPE, node_name,
                source_disk_image, have_compute_img),
            request_id=node_name)
        req_cnt += 1

    try:
        for i, batch in enumerate(batch_list):
            batch.execute(http=http)
            if i < (len(batch_list) - 1):
                time.sleep(30)
    except Exception, e:
        logging.exception("error in add batch: " + str(e))

# [END add_instances]

# [START main]
def main(arg_nodes):
    logging.debug("Bursting out:" + arg_nodes)
    compute = googleapiclient.discovery.build('compute', 'v1',
                                              http=authorized_http,
                                              cache_discovery=False)

    # Get node list
    show_hostname_cmd = "{} show hostnames {}".format(SCONTROL, arg_nodes)
    nodes_str = subprocess.check_output(shlex.split(show_hostname_cmd))
    node_list = nodes_str.splitlines()

    have_compute_img = False
    try:
        image_response = compute.images().getFromFamily(
            project = PROJECT,
            family = CLUSTER_NAME + "-compute-image-family").execute()
        if image_response['status'] != "READY":
            logging.debug("image not ready, using the startup script")
            raise Exception("image not ready")
        source_disk_image = image_response['selfLink']
        have_compute_img = True
    except:
        image_response = compute.images().getFromFamily(
            project='centos-cloud', family='centos-7').execute()
        source_disk_image = image_response['selfLink']

    while True:
        add_instances(compute, source_disk_image, have_compute_img, node_list)
        if not len(retry_list):
            break;

        logging.debug("got {} nodes to retry ({})".
                      format(len(retry_list),",".join(retry_list)))
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
