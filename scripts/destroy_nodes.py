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
import logging
from pathlib import Path
from time import sleep

from suspend import (
    batch_execute, delete_instance_op, truncate_iter, wait_for_operations
)
from util import compute, config_root_logger, project, parse_self_link

logger_name = Path(__file__).name
log = logging.getLogger(logger_name)


def delete_instances(compute_list):
    log.info("Deleting {0} compute instances:\n{1}".format(
        len(compute_list), '\n'.join(compute_list)))

    ops = {}
    for self_link in compute_list:
        (project, zone, name) = parse_self_link(self_link)
        ops[self_link] = delete_instance_op(
            instance=name, project=project, zone=zone)
    done, failed = batch_execute(ops)
    if failed:
        failed_nodes = [f"{n}: {e}" for n, (_, e) in failed.items()]
        node_str = '\n'.join(str(el)
                             for el in truncate_iter(failed_nodes, 5))
        log.error(f"some nodes failed to delete: {node_str}")
    wait_for_operations(done.values())


def main(args):
    # NOTE: It is not technically possible to filter by metadata or other
    #       complex nested items
    result = compute.instances().aggregatedList(
        project=project,
        filter=f"labels.cluster_id={args.cluster_id}"
    ).execute()

    compute_list = []
    for item in result['items'].values():
        instances = item.get('instances')
        if instances is not None:
            for instance in instances:
                try:
                    metadata = {
                        item['key']: item['value'] for item in instance['metadata']['items']
                    }
                except KeyError:
                    metadata = {}

                if metadata.get('instance_type') == 'compute':
                    compute_list.append(instance['selfLink'])

    delete_instances(compute_list)

    sleep_dur = 30
    log.info(f"Done. Sleeping for {sleep_dur} seconds.")
    sleep(sleep_dur)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('cluster_id',
                        help="The cluster ID, of which the node belong to")
    parser.add_argument('--debug', '-d', dest='debug', action='store_true',
                        help='Enable debugging output')

    args = parser.parse_args()

    logfile = (Path(__file__).parent / logger_name).with_suffix('.log')
    if args.debug:
        config_root_logger(logger_name, level='DEBUG', util_level='DEBUG',
                           logfile=logfile)
    else:
        config_root_logger(logger_name, level='INFO', util_level='ERROR',
                           logfile=logfile)

    main(args)
