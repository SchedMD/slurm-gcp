#!/usr/bin/env python

# Copyright 2018 SchedMD LLC.
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

import logging
import re
import shlex
import socket
import subprocess

SCONTROL     = '/apps/slurm/current/bin/scontrol'
LOGFILE      = '/var/log/slurm/slurmd-stop.log'

def main():
    node_name = socket.gethostname()
    try:
        logging.debug("node is shutting down")

        cmd = "{} -o show nodes {}".format(SCONTROL, node_name)
        output = subprocess.check_output(shlex.split(cmd))

        #  Don't mark down if node is in power save state already --
        #  meaning that Slurm is tearing down the node because of idle
        #  time.
        if re.search("State=\S*POWER\S*\s", output):
            logging.debug("node in power save state, not marking down")
            return

        # Only power_down cloud nodes
        is_cloud = bool(re.search("State=\S*CLOUD\S*\s", output))
        if is_cloud:
            logging.debug("marking node for power down")
            cmd = "{} update node={} state=power_down".format(
                SCONTROL, node_name)
            subprocess.call(shlex.split(cmd))

        # Don't mark node as down unless it's not a cloud node or the cloud
        # node is idle. Otherwise the node could get marked as down after
        # the node is powered down.
        is_idle = bool(re.search("State=\S*IDLE\S*\s", output))
        if not is_cloud or not is_idle:
            logging.debug("marking node down")
            cmd = "{} update node={} state=down reason='Instance is stopped/preempted'".format(
                SCONTROL, node_name)
            subprocess.call(shlex.split(cmd))

            logging.debug("node marked down")

    except Exception, e:
        logging.error("something went wrong: ({})".format(str(e)))


if __name__ == '__main__':
    logging.basicConfig(
        filename=LOGFILE,
        format='%(asctime)s %(name)s %(levelname)s: %(message)s',
        level=logging.DEBUG)

    main()
