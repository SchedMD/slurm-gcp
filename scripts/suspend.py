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

# [START removed_instances]
def removed_instances(request_id, response, exception):
    if exception is not None:
        logging.error("exception: " + str(exception))
# [END removed_instances]

# [START main]
def main(short_node_list):
    logging.debug("deleting nodes:" + short_node_list)
    compute = googleapiclient.discovery.build('compute', 'v1',
                                              cache_discovery=False)

    # Get node list
    show_hostname_cmd = "%s show hostname %s" % (SCONTROL, short_node_list)
    node_list = subprocess.check_output(shlex.split(show_hostname_cmd))

    batch = compute.new_batch_http_request(callback=removed_instances)
    for node_name in node_list.splitlines():
        try:
            batch.add(compute.instances().delete(project=PROJECT, zone=ZONE,
                                                 instance=node_name))
        except Exception, e:
            logging.exception("error during release of {} ({})".format(
                node_name, str(e)))

    batch.execute()

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
