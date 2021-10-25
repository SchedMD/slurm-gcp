#!/usr/bin/env python3
# Copyright 2021 SchedMD LLC.
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
import googleapiclient.discovery
import logging
import sys
import time
from pathlib import Path

import util

logger_name = Path(__file__).name
log = logging.getLogger(logger_name)
LOGFILE = (Path(__file__).parent / logger_name).with_suffix('.log')
TOT_REQ_CNT = 1000

OPERATIONS = {}
RETRY_LIST = []

compute = googleapiclient.discovery.build('compute', 'v1', cache_discovery=False)


def delete_instances_cb(request_id, response, exception):
    if exception is not None:
        log.error(f"delete exception for node {request_id}: {exception}")
        if "Rate Limit Exceeded" in str(exception) or "Quota exceeded" in str(exception):
            RETRY_LIST.append(request_id)
    else:
        OPERATIONS[request_id] = response
# [END delete_instances_cb]


def delete_instances(node_list):
    batch_list = []
    curr_batch = 0
    req_cnt = 0
    batch_list.insert(
        curr_batch,
        compute.new_batch_http_request(callback=delete_instances_cb))

    for node in node_list:
        log.info(f"terminating node: {node}")
        """
        DELETE https://compute.googleapis.com/compute/v1/projects/{project}/zones/{zone}/instances/{resourceId}
        """
        node_uri_split = node.split('/')
        node_dict = dict({
            'project': node_uri_split[-5],
            'zone': node_uri_split[-3],
            'resourceId': node_uri_split[-1],
        })

        if req_cnt >= TOT_REQ_CNT:
            req_cnt = 0
            curr_batch += 1
            batch_list.insert(
                curr_batch,
                compute.new_batch_http_request(callback=delete_instances_cb))

        batch_list[curr_batch].add(
            compute.instances().delete(
                project=node_dict['project'],
                zone=node_dict['zone'],
                instance=node_dict['resourceId']
            ),
            request_id=f"{node_dict['project']}/{node_dict['zone']}/{node_dict['resourceId']}"
        )

        req_cnt += 1

    try:
        for i, batch in enumerate(batch_list):
            util.ensure_execute(batch)
            if i < (len(batch_list) - 1):
                time.sleep(30)
    except Exception:
        log.exception("error in batch:")
# [END delete_instances]


def get_instances(project, cluster_name):
    instance_list = []
    result = compute.instances().aggregatedList(
        project=project,
        filter=f"name={cluster_name}-*"
    ).execute()

    for item in result['items'].values():
        instances = item.get('instances')
        if instances is not None:
            for instance in instances:
                instance_list.append(instance['selfLink'])

    return instance_list
# [END get_instance]


def main(project, cluster_name):
    node_list = get_instances(project, cluster_name)

    log.info(f"Found {len(node_list)} compute nodes running on cluster '{cluster_name}'.")
    if len(node_list) > 0:
        log.info("\n".join(node_list))

    while True:
        delete_instances(node_list)
        if not len(RETRY_LIST):
            break

        log.debug("got {} nodes to retry ({})"
                .format(len(RETRY_LIST), ','.join(RETRY_LIST)))
        node_list = list(RETRY_LIST)
        del RETRY_LIST[:]
# [END main]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('project_id',
                        help="Google Cloud Project ID")
    parser.add_argument('cluster_name',
                        help="The cluster name to destroy all nodes of")
    parser.add_argument('--debug', '-d', dest='debug', action='store_true',
                        help='Enable debugging output')

    args = parser.parse_args()

    if args.debug:
        util.config_root_logger(logger_name, level='DEBUG', util_level='DEBUG',
                                logfile=LOGFILE)
    else:
        util.config_root_logger(logger_name, level='INFO', util_level='ERROR',
                                logfile=LOGFILE)
    sys.excepthook = util.handle_exception

    if args.cluster_name is None:
        log.error("No cluster name provided. Aborting...")
        sys.exit(1)
    
    main(args.project_id, args.cluster_name)
# [END __main__]
