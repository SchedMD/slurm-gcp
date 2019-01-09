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

LABELS       = '@LABELS@'

NETWORK_TYPE = 'subnetwork'
NETWORK      = "projects/{}/regions/{}/subnetworks/{}-slurm-subnet".format(PROJECT, REGION, CLUSTER_NAME)

GPU_TYPE     = '@GPU_TYPE@'
GPU_COUNT    = '@GPU_COUNT@'

SCONTROL     = '/apps/slurm/current/bin/scontrol'
LOGFILE      = '/apps/slurm/log/resume.log'

instances = {}
operations = {}

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

    shutdown_script = open(
        '/apps/slurm/scripts/slurmd-stop.py', 'r').read()
    config['metadata']['items'].append({
        'key': 'shutdown-script',
        'value': shutdown_script
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
        config['labels'] = {instance_name: LABELS},

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

    if EXTERNAL_IP or SHARED_VPC_HOST_PROJ:
        config['networkInterfaces'][0]['accessConfigs'] = [
            {'type': 'ONE_TO_ONE_NAT', 'name': 'External NAT'}
        ]

    return compute.instances().insert(
        project=project,
        zone=zone,
        body=config)
# [END create_instance]

# [START wait_for_operation]
def wait_for_operation(compute, project, zone, operation):
    while True:
        result = compute.zoneOperations().get(
            project=project,
            zone=zone,
            operation=operation).execute()

        if result['status'] == 'DONE':
            if 'error' in result:
                raise Exception(result['error'])
            return result

        time.sleep(1)
# [END wait_for_operation]

# [START added_instances]
def added_instances(request_id, response, exception):
    if exception is not None:
        logging.debug("add/start exception: " + str(exception))
    else:
        operations[request_id] = response
# [END added_instances]

# [START get_instances]
def get_instances(request_id, response, exception):
    if exception is not None:
        logging.debug("get exception: " + str(exception))
    else:
        instances[response['name']] = response['status']
# [END get_instances]

# [START main]
def main(short_node_list):
    logging.info("Bursting out:" + short_node_list)
    compute = googleapiclient.discovery.build('compute', 'v1',
                                              http=authorized_http,
                                              cache_discovery=False)

    # Get node list
    show_hostname_cmd = "{} show hostname {}".format(SCONTROL, short_node_list)
    node_list = subprocess.check_output(shlex.split(show_hostname_cmd))

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

    # see if the nodes already exist
    get_batch = compute.new_batch_http_request(callback=get_instances)
    for node_name in node_list.splitlines():
        get_batch.add(compute.instances().get(
            project=PROJECT, zone=ZONE, instance=node_name,
            fields='name,status'))
    try:
        get_batch.execute()
    except Exception, e:
        logging.exception("error in get instances: " + str(e))

    add_batch = compute.new_batch_http_request(callback=added_instances)
    for node_name in node_list.splitlines():
        if node_name in instances:
            logging.debug("node {} already exists in state {}".format(
                node_name, instances[node_name]))
            if instances[node_name] != "RUNNING":
                add_batch.add(
                    compute.instances().start(
                        project=PROJECT, zone=ZONE, instance=node_name),
                    request_id=node_name)
        else:
            add_batch.add(
                create_instance(
                    compute, PROJECT, ZONE, MACHINE_TYPE, node_name,
                    source_disk_image, have_compute_img),
                request_id=node_name)
    try:
        add_batch.execute(http=http)
    except Exception, e:
        logging.exception("error in add batch: " + str(e))

    for node_name in operations:
        try:
            operation = operations[node_name]
            wait_for_operation(compute, PROJECT, ZONE, operation['name'])
        except Exception, e:
            logging.debug("{} operation exception: {}".format(
                node_name, str(e)))
            cmd = "{} update node={} state=down reason='{}'".format(
                SCONTROL, node_name, str(e))
            subprocess.call(shlex.split(cmd))

    logging.debug("done adding instances")
# [END main]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('nodes', help='Nodes to burst')

    args = parser.parse_args()
    logging.basicConfig(
        filename=LOGFILE,
        format='%(asctime)s %(name)s %(levelname)s: %(message)s',
        level=logging.ERROR)

    main(args.nodes)
