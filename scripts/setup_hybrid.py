#!/usr/bin/env python3

# Copyright 2017 SchedMD LLC
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
import sys
from pathlib import Path
from datetime import datetime
import json
import setup
import util
from util import project, lkp, config_root_logger, handle_exception
from slurmeventd import publish_message


filename = Path(__file__).name
logfile = Path(filename).with_suffix('.log')
log = logging.getLogger(filename)
setup.log.disabled = False
util.log.disabled = False


def main(args):
    params = {
        'no_comma_params': args.no_comma_params,
        'ResumeRate': args.ResumeRate,
        'ResumeTimeout': args.ResumeTimeout,
        'SuspendRate': args.SuspendRate,
        'SuspendTimeout': args.SuspendTimeout,
    }
    log.info("Generating new cloud.conf for slurm.conf")
    setup.gen_cloud_conf(lkp, params)

    log.info("Generating new cloud gres.conf for gres.conf")
    setup.install_gres_conf(lkp)

    # Send restart message to cluster topic
    message_json = json.dumps({
        'request': 'restart',
        'timestamp': datetime.utcnow().isoformat(),
    })
    publish_message(project, lkp.cfg.pubsub_topic_id, message_json)

    log.info("Done.")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--ResumeRate', default=0,
                        help='The rate at which nodes in power save mode are returned to normal operation.')
    parser.add_argument('--ResumeTimeout', default=300,
                        help='Maximum time permitted (in seconds) between when a node resume request is issued and when the node is actually available for use.')
    parser.add_argument('--SuspendRate', default=0,
                        help='The rate at which nodes are placed into power save mode by SuspendProgram.')
    parser.add_argument('--SuspendTimeout', default=300,
                        help='Maximum time permitted (in seconds) between when a node suspend request is issued and when the node is shutdown.')
    parser.add_argument('--no-comma-params', action='store_true',
                        help='Do not generate slurm parameters that are comma seperated.')
    parser.add_argument('--debug', '-d', dest='debug', action='store_true',
                        help='Enable debugging output')

    args = parser.parse_args()

    if args.debug:
        config_root_logger(filename, level='DEBUG', util_level='DEBUG',
                           logfile=logfile)
    else:
        config_root_logger(filename, level='INFO', util_level='ERROR',
                           logfile=logfile)
    sys.excepthook = handle_exception

    main(args)
