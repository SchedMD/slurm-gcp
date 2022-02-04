#!/usr/bin/env python3

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
import os
import sys
from pathlib import Path
from itertools import groupby

from addict import Dict as NSDict

import util
from util import run, chunked
from util import cfg, lkp, compute
from util import batch_execute, seperate, split_nodelist, is_exclusive_node


SCONTROL = Path(cfg.slurm_bin_dir if cfg else '')/'scontrol'

filename = Path(__file__).name
LOGFILE = (Path(cfg.slurm_log_dir if cfg else '.')/filename).with_suffix('.log')

log = logging.getLogger(filename)

BULK_INSERT_LIMIT = 1000


def instance_properties(model):
    partition = lkp.node_partition(model)
    template = lkp.node_template(model)
    template_info = lkp.template_info(template)

    props = NSDict()

    props.networkInterfaces = [{
        'subnetwork': partition.subnetwork,
    }]

    slurm_metadata = {
        'slurm_cluster_id': cfg.slurm_cluster_id,
        'slurm_cluster_name': cfg.slurm_cluster_name,
        'slurm_instance_role': 'compute',
        'startup-script': (Path(cfg.slurm_scripts_dir or util.dirs.scripts)/'startup.sh').read_text(),
        'VmDnsSetting': 'GlobalOnly',
    }
    info_metadata = {}
    for i in template_info.metadata['items']:
        key = i.get('key')
        value = i.get('value')
        info_metadata[key] = value

    props_metadata = {**info_metadata, **slurm_metadata}
    props.metadata = {
        'items': [
            NSDict({'key': k, 'value': v}) for k, v in props_metadata.items()
        ]
    }

    labels = {
        'slurm_cluster_id': cfg.slurm_cluster_id,
        'slurm_cluster_name': cfg.slurm_cluster_name,
        'slurm_instance_role': 'compute',
    }
    props.labels = {**template_info.labels, **labels}

    return props


def per_instance_properties(node, placement_groups=None):
    props = NSDict()

    if placement_groups:
        # certain properties are constrained
        props.scheduling = {
            'onHostMaintenance': 'TERMINATE',
            'automaticRestart': False,
        }
        props.resourcePolicies = [
            placement_groups[node],
        ]

    return props


def create_instances_request(nodes, placement_groups=None):
    """ Call regionInstances.bulkInsert to create instances """
    assert len(nodes) > 0
    assert len(nodes) <= BULK_INSERT_LIMIT
    # model here indicates any node that can be used to describe the rest
    model = next(iter(nodes))
    template = lkp.node_template(model)
    region = lkp.node_region(model)

    body = NSDict()
    body.count = len(nodes)

    # source of instance properties
    body.sourceInstanceTemplate = template

    # overwrites properties accross all instances
    body.instanceProperties = instance_properties(model)

    # key is instance name, value overwrites properties
    body.perInstanceProperties = {
        k: per_instance_properties(k, placement_groups) for k in nodes}

    request = compute.regionInstances().bulkInsert(
        project=cfg.project, region=region, body=body.to_dict()
    )
    return request


def expand_nodelist(nodelist):
    """ expand nodes in hostlist to hostnames """
    if nodelist is None:
        return []

    # TODO use a python library instead?
    nodes = run(f"{SCONTROL} show hostnames {nodelist}").stdout.splitlines()
    return nodes


def resume_nodes(nodelist, placement_groups=None):
    """ resume nodes in nodelist """
    def ident_key(n):
        # ident here will refer to the combination of partition and group
        return lkp.node_partition_name(n), lkp.node_group_name(n),

    # support already expanded list
    if isinstance(nodelist, str):
        log.info(f"resume {nodelist}")
        nodelist = expand_nodelist(nodelist)

    nodes = sorted(nodelist, key=ident_key)
    if len(nodes) == 0:
        return
    grouped_nodes = [
        (ident, chunk)
        for ident, nodes in groupby(nodes, ident_key)
        for chunk in chunked(nodes, n=BULK_INSERT_LIMIT)
    ]
    log.debug(f"grouped_nodes: {grouped_nodes}")

    inserts = [
        create_instances_request(nodes, placement_groups)
        for _, nodes in grouped_nodes
    ]
    done, failed = batch_execute(inserts)
    if failed:
        failed_reqs = [f"{e}" for _, (_, e) in failed.items()]
        log.error("bulkInsert failures: {}".format('\n'.join(failed_reqs)))


def create_placement_request(pg_name, region, count):
    config = {
        'name': pg_name,
        'region': region,
        'groupPlacementPolicy': {
            'collocation': 'COLLOCATED',
            'vmCount': count,
        }
    }
    return compute.resourcePolicies().insert(
        project=cfg.project, region=region, body=config
    )


def create_placement_groups(job_id, node_list, partition_name):
    PLACEMENT_MAX_CNT = 22
    groups = {
        f'{cfg.slurm_cluster_name}-{partition_name}-{job_id}-{i}': nodes
        for i, nodes in enumerate(chunked(node_list, n=PLACEMENT_MAX_CNT))
    }
    reverse_groups = {
        node: group for group, nodes in groups.items() for node in nodes
    }

    model = next(iter(node_list))
    region = lkp.node_region(model)

    requests = [
        create_placement_request(group, region, len(incl_nodes))
        for group, incl_nodes in groups.items()
    ]
    done, failed = batch_execute(requests)
    if failed:
        reqs = [f"{e}" for _, e in failed.values()]
        log.fatal("failed to create placement policies: {}".format(
            '\n'.join(reqs)
        ))
    return reverse_groups


def valid_placement_nodes(nodelist):
    machine_types = {
        lkp.node_prefix(node): lkp.node_template_info(node).machineType
        for node in split_nodelist(nodelist)
    }
    fail = False
    for prefix, machine_type in machine_types.items():
        if machine_type.split('-')[0] not in ('c2', 'c2d'):
            log.error(
                "Unsupported machine type for placement policy: "
                f"{machine_type}."
            )
            fail = True
    if fail:
        log.error("Please use c2 or c2d machine types with placement policy")
        return False
    return True


def prolog_resume_nodes(nodelist, job_id):
    """resume exclusive nodes in the node list"""
    # called from PrologSlurmctld, these nodes are expected to be in the same
    # partition and part of the same job
    nodes = expand_nodelist(nodelist)
    if len(nodes) == 0:
        return
    log.info(f"exclusive resume {nodelist} {job_id}")

    model = next(iter(nodes))
    partition = lkp.node_partition(model)
    placement_groups = None
    if partition.enable_placement_groups:
        placement_groups = create_placement_groups(
            job_id, nodes, partition.partition_name)
        if not valid_placement_nodes(nodelist):
            return
    resume_nodes(nodes, placement_groups)


def main(nodelist, job_id):
    """ main called when run as script """
    log.debug(f"main {nodelist} {job_id}")
    # nodes are split between normal and exclusive
    # exclusive nodes are handled by PrologSlurmctld
    node_groups = split_nodelist(nodelist)
    normal, exclusive = seperate(is_exclusive_node, node_groups)
    if job_id is not None:
        if exclusive:
            prolog_resume_nodes(','.join(exclusive), job_id)
    else:
        if normal:
            resume_nodes(','.join(normal))


parser = argparse.ArgumentParser(
    description=__doc__,
    formatter_class=argparse.RawDescriptionHelpFormatter)
parser.add_argument(
    'nodelist', help="list of nodes to resume"
)
parser.add_argument(
    'job_id', nargs='?', default=None,
    help="Optional job id for node list. Implies that PrologSlurmctld called program"
)
parser.add_argument('--debug', '-d', dest='debug', action='store_true',
                    help='Enable debugging output')


if __name__ == '__main__':
    if "SLURM_JOB_NODELIST" in os.environ:
        argv = [
            *sys.argv[1:],
            os.environ['SLURM_JOB_NODELIST'],
            os.environ['SLURM_JOB_ID'],
        ]
        args = parser.parse_args(argv)
    else:
        args = parser.parse_args()

    if args.debug:
        util.config_root_logger(filename, level='DEBUG', util_level='DEBUG',
                                logfile=LOGFILE)
    else:
        util.config_root_logger(filename, level='INFO', util_level='ERROR',
                                logfile=LOGFILE)
    sys.excepthook = util.handle_exception

    main(args.nodelist, args.job_id)
