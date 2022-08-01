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
from time import sleep
from suspend import (
    batch_execute,
    delete_instance_request,
    truncate_iter,
    wait_for_operations,
)
from util import lkp, compute, config_root_logger, parse_self_link

logger_name = Path(__file__).name
log = logging.getLogger(logger_name)


def delete_instances(compute_list):
    log.info(
        "Deleting {0} compute instances:\n{1}".format(
            len(compute_list), "\n".join(compute_list)
        )
    )

    ops = {}
    for self_link in compute_list:
        link_info = parse_self_link(self_link)
        ops[self_link] = delete_instance_request(
            instance=link_info.instance, project=link_info.project, zone=link_info.zone
        )
    done, failed = batch_execute(ops)
    if failed:
        failed_nodes = [f"{n}: {e}" for n, (_, e) in failed.items()]
        node_str = "\n".join(str(el) for el in truncate_iter(failed_nodes, 5))
        log.error(f"some nodes failed to delete: {node_str}")
    wait_for_operations(done.values())


def main(args):
    required_map = {
        "labels.slurm_cluster_name": args.slurm_cluster_name,
        "labels.slurm_instance_role": "compute",
    }
    required_list = [f"{k}={v}" for k, v in required_map.items()]
    required_logic = " AND ".join(required_list)

    target_list = (
        " OR ".join([f"name={x}" for x in args.target.split(",")])
        if args.target
        else ""
    )
    target_logic = f"AND ({target_list})" if args.target else ""

    exclude_list = (
        " AND ".join([f"name!={x}" for x in args.exclude.split(",")])
        if args.exclude
        else ""
    )
    exclude_logic = f"AND ({exclude_list})" if args.exclude else ""

    filter = f"{required_logic} {target_logic} {exclude_logic}"
    log.debug(f'filter = "{filter}"')

    # NOTE: It is not technically possible to filter by metadata or other
    #       complex nested items
    result = (
        compute.instances().aggregatedList(project=lkp.project, filter=filter).execute()
    )

    compute_list = []
    for item in result["items"].values():
        instances = item.get("instances")
        if instances is not None:
            for instance in instances:
                compute_list.append(instance["selfLink"])

    delete_instances(compute_list)

    if len(compute_list) > 0:
        sleep_dur = 30
        log.info(f"Done. Sleeping for {sleep_dur} seconds.")
        sleep(sleep_dur)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("slurm_cluster_name", help="Slurm cluster name label filter")
    parser.add_argument(
        "--target", help="NodeNames targeted for destruction", type=str, default=None
    )
    parser.add_argument(
        "--exclude", help="NodeNames excluded from destruction", type=str, default=None
    )
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
