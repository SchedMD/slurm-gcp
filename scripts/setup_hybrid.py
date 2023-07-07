#!/usr/bin/env python3

# Copyright (C) SchedMD LLC.
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
import setup
import util
from util import lkp, config_root_logger, handle_exception


filename = Path(__file__).name
logfile = Path(filename).with_suffix(".log")
log = logging.getLogger(filename)
setup.log.disabled = False
util.log.disabled = False


def main(args):
    log.info("Generating new cloud.conf for slurm.conf")
    setup.gen_cloud_conf(lkp)

    log.info("Generating new cloud_gres.conf for gres.conf")
    setup.gen_cloud_gres_conf(lkp)

    log.info("Generating new cloud_topology.conf for topology.conf")
    setup.gen_topology_conf(lkp)

    log.info("Done.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--debug",
        "-d",
        dest="debug",
        action="store_true",
        help="Enable debugging output",
    )

    args = parser.parse_args()

    if args.debug:
        config_root_logger(filename, level="DEBUG", logfile=logfile)
    else:
        config_root_logger(filename, level="INFO", logfile=logfile)
    sys.excepthook = handle_exception

    main(args)
