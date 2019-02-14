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
retry_list = []

# [START delete_instances_cb]
def delete_instances_cb(request_id, response, exception):
    if exception is not None:
        logging.error("delete exception for node {}: {}".format(request_id,
                                                                str(exception)))
        if "Rate Limit Exceeded" in str(exception):
            retry_list.append(request_id)
    else:
        operations[request_id] = response
# [END delete_instances_cb]

# [START delete_instances]
def delete_instances(compute, node_list):

    batch_list = []
    curr_batch = 0
    req_cnt = 0
    batch_list.insert(
        curr_batch, compute.new_batch_http_request(callback=delete_instances_cb))

    for node_name in node_list:
        if req_cnt >= TOT_REQ_CNT:
            req_cnt = 0
            curr_batch += 1
            batch_list.insert(
                curr_batch,
                compute.new_batch_http_request(callback=delete_instances_cb))

        batch_list[curr_batch].add(
            compute.instances().delete(project=PROJECT, zone=ZONE,
                                       instance=node_name),
            request_id=node_name)
        req_cnt += 1

    try:
        for i, batch in enumerate(batch_list):
            batch.execute()
            if i < (len(batch_list) - 1):
                time.sleep(30)
    except Exception, e:
        logging.exception("error in batch: " + str(e))

# [END delete_instances]

# [START main]
def main(arg_nodes):
    logging.debug("deleting nodes:" + arg_nodes)
    compute = googleapiclient.discovery.build('compute', 'v1',
                                              cache_discovery=False)

    # Get node list
    show_hostname_cmd = "%s show hostnames %s" % (SCONTROL, arg_nodes)
    nodes_str = subprocess.check_output(shlex.split(show_hostname_cmd))
    node_list = nodes_str.splitlines()

    while True:
        delete_instances(compute, node_list)
        if not len(retry_list):
            break;

        logging.debug("got {} nodes to retry ({})".
                      format(len(retry_list),",".join(retry_list)))
        node_list = list(retry_list)
        del retry_list[:]

    logging.debug("done deleting instances")

# [END main]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('nodes', help='Nodes to release')

    args = parser.parse_args()

    # silence module logging
    for logger in logging.Logger.manager.loggerDict:
        logging.getLogger(logger).setLevel(logging.WARNING)

    logging.basicConfig(
        filename=LOGFILE,
        format='%(asctime)s %(name)s %(levelname)s: %(message)s',
        level=logging.DEBUG)

    main(args.nodes)
