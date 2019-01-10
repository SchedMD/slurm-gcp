#!/usr/bin/env python

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
import shlex
import subprocess
import time

import googleapiclient.discovery

PROJECT      = '@PROJECT@'
ZONE         = '@ZONE@'
SCONTROL     = '/apps/slurm/current/bin/scontrol'
LOGFILE      = '/apps/slurm/log/suspend.log'

TOT_REQ_CNT = 1000

operations = {}

# [START removed_instances]
def removed_instances(request_id, response, exception):
    if exception is not None:
        logging.error("exception: " + str(exception))
    else:
        operations[request_id] = response
# [END removed_instances]

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

# [START main]
def main(short_node_list):
    logging.debug("deleting nodes:" + short_node_list)
    compute = googleapiclient.discovery.build('compute', 'v1',
                                              cache_discovery=False)

    # Get node list
    show_hostname_cmd = "%s show hostname %s" % (SCONTROL, short_node_list)
    node_list = subprocess.check_output(shlex.split(show_hostname_cmd))

    batch_list = []
    curr_batch = 0
    req_cnt = 0
    batch_list.insert(
        curr_batch, compute.new_batch_http_request(callback=removed_instances))
    for node_name in node_list.splitlines():
        try:
            batch_list[curr_batch].add(
                compute.instances().delete(project=PROJECT, zone=ZONE,
                                           instance=node_name),
                request_id=node_name)
            req_cnt += 1
            if req_cnt >= TOT_REQ_CNT:
                req_cnt = 0
                curr_batch += 1
                batch_list.insert(
                    curr_batch,
                    compute.new_batch_http_request(callback=removed_instances))

        except Exception, e:
            logging.exception("error during release of {} ({})".format(
                node_name, str(e)))

    try:
        for batch in batch_list:
            batch.execute()
    except Exception, e:
        logging.exception("error in batch: " + str(e))

    for node_name in operations:
        try:
            operation = operations[node_name]
            wait_for_operation(compute, PROJECT, ZONE, operation['name'])
        except Exception, e:
            logging.debug("{} operation exception: {}".format(
                node_name, str(e)))

    logging.debug("done deleting instances")

# [END main]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('nodes', help='Nodes to release')

    args = parser.parse_args()
    logging.basicConfig(
        filename=LOGFILE,
        format='%(asctime)s %(name)s %(levelname)s: %(message)s',
        level=logging.ERROR)

    main(args.nodes)
