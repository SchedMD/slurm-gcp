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

import util
from util import (
    get_insert_operations,
    parse_self_link,
    run,
    chunked,
    separate,
    batch_execute,
    execute_with_futures,
    split_nodelist,
    is_exclusive_node,
    subscription_create,
    wait_for_operation,
)
from util import cfg, lkp, compute, NSDict

filename = Path(__file__).name
LOGFILE = (Path(cfg.slurm_log_dir if cfg else ".") / filename).with_suffix(".log")

log = logging.getLogger(filename)

BULK_INSERT_LIMIT = 1000


def instance_properties(partition, template):
    template_info = lkp.template_info(template)

    props = NSDict()

    props.networkInterfaces = [
        {
            "subnetwork": partition.subnetwork,
        }
    ]

    slurm_metadata = {
        "slurm_cluster_id": cfg.slurm_cluster_id,
        "slurm_cluster_name": cfg.slurm_cluster_name,
        "slurm_instance_role": "compute",
        "startup-script": (
            Path(cfg.slurm_scripts_dir or util.dirs.scripts) / "startup.sh"
        ).read_text(),
        "VmDnsSetting": "GlobalOnly",
    }
    info_metadata = {}
    for i in template_info.metadata["items"]:
        key = i.get("key")
        value = i.get("value")
        info_metadata[key] = value

    props_metadata = {**info_metadata, **slurm_metadata}
    props.metadata = {
        "items": [NSDict({"key": k, "value": v}) for k, v in props_metadata.items()]
    }

    labels = {
        "slurm_cluster_id": cfg.slurm_cluster_id,
        "slurm_cluster_name": cfg.slurm_cluster_name,
        "slurm_instance_role": "compute",
    }
    props.labels = {**template_info.labels, **labels}

    return props


def per_instance_properties(node, placement_groups=None):
    props = NSDict()

    if placement_groups:
        # certain properties are constrained
        props.scheduling = {
            "onHostMaintenance": "TERMINATE",
            "automaticRestart": False,
        }
        props.resourcePolicies = [
            placement_groups[node],
        ]

    return props


def create_instances_request(nodes, placement_groups=None, exclusive=False):
    """Call regionInstances.bulkInsert to create instances"""
    assert len(nodes) > 0
    assert len(nodes) <= BULK_INSERT_LIMIT
    # model here indicates any node that can be used to describe the rest
    model = next(iter(nodes))
    partition = lkp.node_partition(model)
    template = lkp.node_template(model)
    region = lkp.node_region(model)

    body = NSDict()
    body.count = len(nodes)
    if not exclusive:
        body.minCount = 1

    # source of instance properties
    body.sourceInstanceTemplate = template

    # overwrites properties accross all instances
    body.instanceProperties = instance_properties(partition, template)

    # key is instance name, value overwrites properties
    body.perInstanceProperties = {
        k: per_instance_properties(k, placement_groups) for k in nodes
    }

    zones = {
        **{
            f"zones/{zone}": {"preference": "ALLOW"}
            for zone in partition.zone_policy_allow or []
        },
        **{
            f"zones/{zone}": {"preference": "DENY"}
            for zone in partition.zone_policy_deny or []
        },
    }
    if zones:
        body.locationPolicy = {"locations": zones}

    request = compute.regionInstances().bulkInsert(
        project=cfg.project, region=region, body=body.to_dict()
    )
    return request


def expand_nodelist(nodelist):
    """expand nodes in hostlist to hostnames"""
    if not nodelist:
        return []

    # TODO use a python library instead?
    nodes = run(f"{lkp.scontrol} show hostnames {nodelist}").stdout.splitlines()
    return nodes


def resume_nodes(nodelist, placement_groups=None, exclusive=False):
    """resume nodes in nodelist"""

    def ident_key(n):
        # ident here will refer to the combination of partition and group
        return "-".join(
            (
                lkp.node_partition_name(n),
                lkp.node_group_name(n),
            )
        )

    # support already expanded list
    nodes = nodelist
    if isinstance(nodes, str):
        nodelist = expand_nodelist(nodelist)

    nodes = sorted(nodelist, key=ident_key)
    if len(nodes) == 0:
        return
    grouped_nodes = {
        ident: chunk
        for ident, nodes in groupby(nodes, ident_key)
        for chunk in chunked(nodes, n=BULK_INSERT_LIMIT)
    }
    log.debug(f"grouped_nodes: {grouped_nodes}")

    # make all bulkInsert requests and execute with batch
    inserts = {
        ident: create_instances_request(nodes, placement_groups, exclusive)
        for ident, nodes in grouped_nodes.items()
    }
    started, failed = batch_execute(inserts)
    if failed:
        failed_reqs = [f"{e}" for _, (_, e) in failed.items()]
        log.error("bulkInsert API failures: {}".format("\n".join(failed_reqs)))
        for ident, (_, exc) in failed.items():
            down_nodes(grouped_nodes[ident], exc._get_reason())

    # wait for all bulkInserts to complete and log any errors
    bulk_operations = [wait_for_operation(op) for op in started.values()]
    for bulk_op in bulk_operations:
        if "error" in bulk_op:
            error = bulk_op["error"]["errors"][0]
            log.error(
                f"bulkInsert operation error: {error['code']} operationName:'{bulk_op['name']}'"
            )

    # Fetch all insert operations from all bulkInserts. Group by error code and log
    successful_inserts, failed_inserts = separate(
        lambda op: "error" in op, get_insert_operations(bulk_operations)
    )
    # Apparently multiple errors are possible... so join with +.
    # grouped_inserts could be made into a dict, but it's not really necessary. Save some memory.
    grouped_inserts = util.groupby_unsorted(
        failed_inserts,
        lambda op: "+".join(err["code"] for err in op["error"]["errors"]),
    )
    for code, failed_ops in grouped_inserts:
        # at least one insert failure
        failed_nodes = [parse_self_link(op["targetLink"]).instance for op in failed_ops]
        hostlist = util.to_hostlist(failed_nodes)
        count = len(failed_nodes)
        log.error(
            f"{count} instances failed to start due to insert operation error: {code} ({hostlist})"
        )
        down_nodes(hostlist, code)
        if log.isEnabledFor(logging.DEBUG):
            msg = "\n".join(
                err["message"] for err in next(failed_ops)["error"]["errors"]
            )
            log.debug(f"{code} message from first node: {msg}")

    # If reconfigure enabled, create subscriptions for successfully started instances
    if lkp.cfg.enable_reconfigure and len(successful_inserts):
        started_nodes = [
            parse_self_link(op["targetLink"]).instance for op in successful_inserts
        ]
        count = len(started_nodes)
        hostlist = util.to_hostlist(started_nodes)
        log.info("create {} subscriptions ({})".format(count, hostlist))
        execute_with_futures(subscription_create, nodes)


def down_nodes(nodelist, reason):
    """set nodes down with reason"""
    if isinstance(nodelist, list):
        nodelist = util.to_hostlist(nodelist)
    run(f"{lkp.scontrol} update nodename={nodelist} state=down reason='{reason}'")


def hold_job(job_id, reason):
    """hold job, set comment to reason"""
    run(f"{lkp.scontrol} hold jobid={job_id}")
    run(f"{lkp.scontrol} update jobid={job_id} comment='{reason}'")


def create_placement_request(pg_name, region):
    config = {
        "name": pg_name,
        "region": region,
        "groupPlacementPolicy": {
            "collocation": "COLLOCATED",
        },
    }
    return compute.resourcePolicies().insert(
        project=cfg.project, region=region, body=config
    )


def create_placement_groups(job_id, node_list, partition_name):
    PLACEMENT_MAX_CNT = 22
    groups = {
        f"{cfg.slurm_cluster_name}-{partition_name}-{job_id}-{i}": nodes
        for i, nodes in enumerate(chunked(node_list, n=PLACEMENT_MAX_CNT))
    }
    reverse_groups = {node: group for group, nodes in groups.items() for node in nodes}

    model = next(iter(node_list))
    region = lkp.node_region(model)

    requests = [
        create_placement_request(group, region) for group, incl_nodes in groups.items()
    ]
    done, failed = batch_execute(requests)
    if failed:
        reqs = [f"{e}" for _, e in failed.values()]
        log.fatal("failed to create placement policies: {}".format("\n".join(reqs)))
    return reverse_groups


def valid_placement_nodes(job_id, nodelist):
    machine_types = {
        lkp.node_prefix(node): lkp.node_template_info(node).machineType
        for node in split_nodelist(nodelist)
    }
    fail = False
    for prefix, machine_type in machine_types.items():
        if machine_type.split("-")[0] not in ("c2", "c2d"):
            log.error(f"Unsupported machine type for placement policy: {machine_type}.")
            fail = True
    if fail:
        log.error("Please use c2 or c2d machine types with placement policy")
        hold_job(
            job_id, "Node machine type in partition does not support placement policy."
        )
        return False
    return True


def prolog_resume_nodes(job_id, nodelist):
    """resume exclusive nodes in the node list"""
    # called from PrologSlurmctld, these nodes are expected to be in the same
    # partition and part of the same job
    nodes = nodelist
    if not isinstance(nodes, list):
        nodes = expand_nodelist(nodes)
    if len(nodes) == 0:
        return

    model = next(iter(nodes))
    partition = lkp.node_partition(model)
    placement_groups = None
    if partition.enable_placement_groups:
        placement_groups = create_placement_groups(
            job_id, nodes, partition.partition_name
        )
        if not valid_placement_nodes(job_id, nodelist):
            return
    resume_nodes(nodes, placement_groups, exclusive=True)


def main(nodelist, job_id, force=False):
    """main called when run as script"""
    log.debug(f"main {nodelist} {job_id}")
    # nodes are split between normal and exclusive
    # exclusive nodes are handled by PrologSlurmctld
    nodes = expand_nodelist(nodelist)
    if force:
        exclusive = normal = nodes
        prelog = "force "
    else:
        normal, exclusive = separate(is_exclusive_node, nodes)
        prelog = ""
    if job_id is None or force:
        if normal:
            hostlist = util.to_hostlist(normal)
            log.info(f"{prelog}resume {hostlist}")
            resume_nodes(normal)
    else:
        if exclusive:
            hostlist = util.to_hostlist(exclusive)
            log.info(f"{prelog}exclusive resume {hostlist} {job_id}")
            prolog_resume_nodes(job_id, exclusive)


parser = argparse.ArgumentParser(
    description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
)
parser.add_argument("nodelist", help="list of nodes to resume")
parser.add_argument(
    "job_id",
    nargs="?",
    default=None,
    help="Optional job id for node list. Implies that PrologSlurmctld called program",
)
parser.add_argument(
    "--force",
    "-f",
    "--static",
    action="store_true",
    help="Force attempted creation of the nodelist, whether nodes are exclusive or not.",
)
parser.add_argument(
    "--debug", "-d", dest="debug", action="store_true", help="Enable debugging output"
)


if __name__ == "__main__":
    if "SLURM_JOB_NODELIST" in os.environ:
        argv = [
            *sys.argv[1:],
            os.environ["SLURM_JOB_NODELIST"],
            os.environ["SLURM_JOB_ID"],
        ]
        args = parser.parse_args(argv)
    else:
        args = parser.parse_args()

    util.chown_slurm(LOGFILE, mode=0o600)
    if args.debug:
        util.config_root_logger(
            filename, level="DEBUG", util_level="DEBUG", logfile=LOGFILE
        )
    else:
        util.config_root_logger(
            filename, level="INFO", util_level="ERROR", logfile=LOGFILE
        )
    sys.excepthook = util.handle_exception

    main(args.nodelist, args.job_id, args.force)
