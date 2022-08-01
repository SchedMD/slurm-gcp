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
from pathlib import Path
from util import (
    config_root_logger,
    execute_with_futures,
    parse_self_link,
    subscription_delete,
    subscription_list,
)

logger_name = Path(__file__).name
log = logging.getLogger(logger_name)


def main(args):
    subscriptions = subscription_list(slurm_cluster_name=args.slurm_cluster_name)
    subscriptions = [s.name for s in subscriptions if "controller" not in s.name]
    log.info(
        "Deleting {0} subscriptions:\n{1}".format(
            len(subscriptions), "\n".join(subscriptions)
        )
    )
    subscriptions = [parse_self_link(s).subscription for s in subscriptions]
    execute_with_futures(subscription_delete, subscriptions)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("slurm_cluster_name", help="Slurm cluster name filter")
    parser.add_argument(
        "--debug",
        "-d",
        dest="debug",
        action="store_true",
        help="Enable debugging output",
    )

    args = parser.parse_args()

    logfile = (Path(__file__).parent / logger_name).with_suffix(".log")
    if args.debug:
        config_root_logger(logger_name, level="DEBUG", logfile=logfile)
    else:
        config_root_logger(logger_name, level="INFO", logfile=logfile)

    main(args)
