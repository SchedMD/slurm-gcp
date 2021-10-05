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
import httplib2
import logging
import os
import sys
import tempfile
import json
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from functools import partial
from itertools import groupby, chain, islice

import googleapiclient.discovery
from google.auth import compute_engine
import google_auth_httplib2
from googleapiclient.http import set_user_agent

from addict import Dict as NSDict

import util
from util import run


cfg = util.Config.load_config(Path(__file__).with_name('config.yaml'))
lkp = util.Lookup(cfg)
PREFIX = Path('/usr/local/bin')
SCONTROL = PREFIX/'scontrol'

LOGFILE = (Path(cfg.log_dir or '')/Path(__file__).name).with_suffix('.log')
SCRIPTS_DIR = Path(__file__).parent.resolve()

TOT_REQ_CNT = 1000

if cfg.google_app_cred_path:
    os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = cfg.google_app_cred_path


def instance_properties(partition):
    region = partition.region
    subnet = partition.subnet_name or f'{cfg.cluster_name}-subnet'

    props = NSDict()
    iface = NSDict()
    iface.subnetwork = (
        f'projects/{cfg.project}/regions/{region}/subnetworks/{subnet}'
    )
    props.networkInterfaces = [iface]

    metadata = NSDict()
    metadata['compute-network-storage'] = json.dump(partition.network_storage)

    props.metadata = [NSDict({'key': k, 'value': v}) for k, v in metadata]
    return props


def create_instances(nodes):
    """ Call regionInstances.bulkInsert to create instances """
    if len(nodes) == 0:
        return
    model = next(iter(nodes))
    template = lkp.node_template_props(model).url
    partition = cfg.partitions[lkp.node_partition(model)]

    body = NSDict()
    body.count = len(nodes)
    body.sourceInstanceTemplate = template
    body.perInstanceProperties = {k: {} for k in nodes}
    body.instanceProperties = instance_properties(partition)

    compute, lock = next(lkp.compute_pool)
    result = util.ensure_execute(compute.regionInstances().bulkInsert(
        project=cfg.project, region=partition.region, body=body
    ))
    lock.release()
    return result


def expand_nodelist(nodelist):
    """ expand nodes in hostlist to hostnames """
    nodes = run(f"{SCONTROL} show hostnames {nodelist}", check=True,
                get_stdout=True).stdout.splitlines()
    return nodes


def chunks(it, n=TOT_REQ_CNT):
    """ group iterator into chunks of max size n """
    it = iter(it)
    while (chunk := list(islice(it, n))):
        yield chunk


def resume_nodes(nodelist):
    """ resume nodes in nodelist """
    nodes = expand_nodelist(nodelist)

    def ident_key(n):
        # ident here will refer to the combination of template and partition
        return lkp.node_template(n), lkp.node_partition(n)
    nodes.sort(key=ident_key)
    grouped_nodes = [
        (ident, chunk)
        for ident, nodes in groupby(nodes, ident_key)
        for chunk in chunks(nodes)
    ]

    with ThreadPoolExecutor() as exe:
        futures = []
        for _, nodes in grouped_nodes:
            futures.append(exe.submit(create_instances, nodes))
        for f in futures:
            f.result()


def prolog_resume_nodes(nodelist, job_id):
    pass


def main(nodelist, job_id):
    """ main called when run as script """
    if job_id is not None:
        prolog_resume_nodes(nodelist, job_id)
    else:
        resume_nodes(nodelist)


if __name__ == '__main__':
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
        util.config_root_logger(level='DEBUG', util_level='DEBUG',
                                logfile=LOGFILE)
    else:
        util.config_root_logger(level='INFO', util_level='ERROR',
                                logfile=LOGFILE)
    log = logging.getLogger(Path(__file__).name)
    sys.excepthook = util.handle_exception

    main(args.nodelist, args.job_id)

