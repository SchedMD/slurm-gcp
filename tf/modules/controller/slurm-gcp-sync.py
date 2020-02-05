#!/usr/bin/python

# Copyright 2019 SchedMD LLC.
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

import fcntl
import httplib2
import logging
import os
import shlex
import subprocess
import sys
import time
import tempfile

import googleapiclient.discovery

CLUSTER_NAME = '@CLUSTER_NAME@'

PROJECT      = '@PROJECT@'
ZONE         = '@ZONE@'

SCONTROL     = '/apps/slurm/current/bin/scontrol'
SINFO        = '/apps/slurm/current/bin/sinfo'
LOGDIR       = '/apps/slurm/log'

TOT_REQ_CNT = 1000

retry_list = []

# [START start_instances_cb]
def start_instances_cb(request_id, response, exception):
    if exception is not None:
        logging.error("start exception: " + str(exception))
        if "Rate Limit Exceeded" in str(exception):
            retry_list.append(request_id)
        elif "was not found" in str(exception):
            subprocess.Popen(
                shlex.split("/apps/slurm/scripts/resume.py {}"
                            .format(request_id)))
# [END start_instances_cb]


# [START start_instances]
def start_instances(compute, node_list):

    req_cnt = 0
    curr_batch = 0
    batch_list = []
    batch_list.insert(
        curr_batch,
        compute.new_batch_http_request(callback=start_instances_cb))

    for node in node_list:
        if req_cnt >= TOT_REQ_CNT:
            req_cnt = 0
            curr_batch += 1
            batch_list.insert(
                curr_batch,
                compute.new_batch_http_request(callback=start_instances_cb))

        batch_list[curr_batch].add(
            compute.instances().start(project=PROJECT, zone=ZONE,
                                      instance=node),
            request_id=node)
        req_cnt += 1
    try:
        for i, batch in enumerate(batch_list):
            batch.execute()
            if i < (len(batch_list) - 1):
                time.sleep(30)
    except Exception, e:
        logging.exception("error in start batch: " + str(e))

# [END start_instances]

# [START main]
def main():
    compute = googleapiclient.discovery.build('compute', 'v1',
                                              cache_discovery=False)

    try:
        s_nodes = dict()
        cmd = "{} --noheader -N -o'%N,%t' | uniq".format(SINFO)
        nodes = subprocess.check_output(cmd, shell=True)
        if nodes:
            s_nodes = dict(n.split(",") for n in nodes.rstrip().splitlines())

        page_token = ""
        g_nodes = []
        while True:
            resp = compute.instances().list(
                      project=PROJECT, zone=ZONE, pageToken=page_token,
                      filter='name={}-compute*'.format(CLUSTER_NAME)).execute()

            if "items" in resp:
                g_nodes.extend(resp['items'])
            if "nextPageToken" in resp:
                page_token = resp['nextPageToken']
                continue

            break;

        to_down = []
        to_idle = []
        to_start = []
        for s_node, s_state in s_nodes.iteritems():
            g_node = next((item for item in g_nodes
                           if item["name"] == s_node),
                          None)

            if ("~" not in s_state):
                # slurm nodes that aren't in power_save and are stopped in GCP:
                #   mark down in slurm
                #   start them in gcp
                if g_node and (g_node['status'] == "TERMINATED"):
                    to_down.append(s_node)
                    to_start.append(s_node)

                # can't check if the node doesn't exist in GCP while the node
                # is booting because it might not have been created yet by the
                # resume script.
                # This should catch the completing states as well.
                if ((g_node == None) and ("#" not in s_state)):
                    to_down.append(s_node)
            elif (g_node == None):
                # find nodes that are down~ in slurm and don't exist in gcp:
                #   mark idle~
                if (s_state == "down~"):
                    to_idle.append(s_node)
                elif ("comp" in s_state):
                    to_down.append(s_node)

        if len(to_down):
            logging.debug("{} stopped/deleted instances ({})".format(
                len(to_down), ",".join(to_down)))
            logging.debug("{} instances to start ({})".format(
                len(to_start), ",".join(to_start)))

            # write hosts to a file that can be given to get a slurm
            # hostlist. Since the number of hosts could be large.
            tmp_file = tempfile.NamedTemporaryFile(mode='w+t', delete=False)
            tmp_file.writelines("\n".join(to_down))
            tmp_file.close()
            logging.debug("tmp_file = {}".format(tmp_file.name))

            cmd = "{} show hostlist {}".format(SCONTROL, tmp_file.name)
            hostlist = subprocess.check_output(shlex.split(cmd))
            logging.debug("hostlist = {}".format(hostlist))
            os.remove(tmp_file.name)

            cmd = "{} update nodename={} state=down reason='Instance stopped/deleted'".format(
                SCONTROL, hostlist)
            subprocess.call(shlex.split(cmd))

            while True:
                start_instances(compute, to_start)
                if not len(retry_list):
                    break;

                logging.debug("got {} nodes to retry ({})".
                              format(len(retry_list),",".join(retry_list)))
                to_start = list(retry_list)
                del retry_list[:]


        if len(to_idle):
            logging.debug("{} down~ instances ({})".format(
                len(to_idle), ",".join(to_idle)))

            # write hosts to a file that can be given to get a slurm
            # hostlist. Since the number of hosts could be large.
            tmp_file = tempfile.NamedTemporaryFile(mode='w+t', delete=False)
            tmp_file.writelines("\n".join(to_idle))
            tmp_file.close()
            logging.debug("tmp_file = {}".format(tmp_file.name))

            cmd = "{} show hostlist {}".format(SCONTROL, tmp_file.name)
            hostlist = subprocess.check_output(shlex.split(cmd))
            logging.debug("hostlist = {}".format(hostlist))
            os.remove(tmp_file.name)

            cmd = "{} update nodename={} state=idle".format(
                SCONTROL, hostlist)
            subprocess.call(shlex.split(cmd))


    except Exception, e:
        logging.error("failed to sync instances ({})".format(str(e)))

# [END main]


if __name__ == '__main__':
    base = os.path.basename(__file__)
    file_name = os.path.splitext(base)[0]

    # silence module logging
    for logger in logging.Logger.manager.loggerDict:
        logging.getLogger(logger).setLevel(logging.WARNING)

    logging.basicConfig(
        filename="{}/{}.log".format(LOGDIR, file_name),
        format='%(asctime)s %(name)s %(levelname)s: %(message)s',
        level=logging.DEBUG)

    # only run one instance at a time
    pid_file = '/tmp/{}.pid'.format(file_name)
    fp = open(pid_file, 'w')
    try:
        fcntl.lockf(fp, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except IOError:
        sys.exit(0)

    main()
