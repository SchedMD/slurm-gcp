#!/usr/bin/env python3

# Copyright (C) SchedMD LLC.
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
from itertools import groupby
from pathlib import Path
from suspend import delete_placement_groups
import yaml

import util
from util import (
    ensure_execute,
    get_insert_operations,
    log_api_request,
    map_with_futures,
    parse_self_link,
    run,
    chunked,
    separate,
    batch_execute,
    execute_with_futures,
    is_exclusive_node,
    subscription_create,
    to_hostlist,
    trim_self_link,
    wait_for_operation,
)
from util import cfg, lkp, NSDict

filename = Path(__file__).name
LOGFILE = (Path(cfg.slurm_log_dir if cfg else ".") / filename).with_suffix(".log")

log = logging.getLogger(filename)

BULK_INSERT_LIMIT = 1000


def instance_properties(partition, model):
    node_group = lkp.node_group(model)
    template = lkp.node_template(model)
    template_info = lkp.template_info(template)

    props = NSDict()

    props.networkInterfaces = [
        {
            "subnetwork": partition.subnetwork,
        }
    ]

    if node_group.bandwidth_tier == "virtio_enabled":
        props.networkInterfaces[0]["nicType"] = "VirtioNet"
    elif node_group.bandwidth_tier in ["tier_1_enabled", "gvnic_enabled"]:
        props.networkInterfaces[0]["nicType"] = "gVNIC"

    if node_group.bandwidth_tier == "tier_1_enabled":
        props.networkPerformanceConfig = {"totalEgressBandwidthTier": "TIER_1"}

    slurm_metadata = {
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
        "slurm_cluster_name": cfg.slurm_cluster_name,
        "slurm_instance_role": "compute",
    }
    props.labels = {**template_info.labels, **labels}

    # provisioningModel=SPOT not supported by perInstanceProperties?
    if node_group.enable_spot_vm:
        util.compute = util.compute_service(version="beta")

        props.scheduling = {
            "automaticRestart": False,
            "instanceTerminationAction": node_group.spot_instance_config.get(
                "termination_action", "STOP"
            ),
            "onHostMaintenance": "TERMINATE",
            "preemptible": True,
            "provisioningModel": "SPOT",
        }

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
    body.instanceProperties = instance_properties(partition, model)

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

    request = util.compute.regionInstances().bulkInsert(
        project=cfg.project, region=region, body=body.to_dict()
    )

    if log.isEnabledFor(logging.DEBUG):
        log.debug(
            f"new request: endpoint={request.methodId} nodes={to_hostlist(nodes)}"
        )
    log_api_request(request)
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
    # support already expanded list
    if isinstance(nodelist, str):
        nodelist = expand_nodelist(nodelist)
    if len(nodelist) == 0:
        return
    nodelist = sorted(nodelist, key=lkp.node_prefix)

    grouped_nodes = {
        f"{prefix}:{i}": chunk
        for prefix, nodes in groupby(nodelist, lkp.node_prefix)
        for i, chunk in enumerate(chunked(nodes, n=BULK_INSERT_LIMIT))
    }
    if log.isEnabledFor(logging.DEBUG):
        # grouped_nodelists is used in later debug logs too
        grouped_nodelists = {
            group: to_hostlist(nodes) for group, nodes in grouped_nodes.items()
        }
        log.debug(
            "node bulk groups: \n{}".format(yaml.safe_dump(grouped_nodelists).rstrip())
        )

    # make all bulkInsert requests and execute with batch
    inserts = {
        group: create_instances_request(nodes, placement_groups, exclusive)
        for group, nodes in grouped_nodes.items()
    }

    bulk_ops = dict(
        zip(inserts.keys(), map_with_futures(ensure_execute, inserts.values()))
    )
    log.debug(f"bulk_ops={yaml.safe_dump(bulk_ops)}")
    started = {group: op for group, (op, err) in bulk_ops.items() if err is None}
    failed = {
        group: (op, err) for group, (op, err) in bulk_ops.items() if err is not None
    }
    if failed:
        failed_reqs = [f"{e}" for _, (_, e) in failed.items()]
        log.error("bulkInsert API failures: {}".format("; ".join(failed_reqs)))
        for ident, (_, exc) in failed.items():
            down_nodes(grouped_nodes[ident], exc._get_reason())

    if log.isEnabledFor(logging.DEBUG):
        for group, op in started.items():
            group_nodes = grouped_nodelists[group]
            name = op["name"]
            gid = op["operationGroupId"]
            log.debug(
                f"new bulkInsert operation started: group={group} nodes={group_nodes} name={name} operationGroupId={gid}"
            )
    # wait for all bulkInserts to complete and log any errors
    bulk_operations = {group: wait_for_operation(op) for group, op in started.items()}
    all_successful_inserts = []

    for group, bulk_op in bulk_operations.items():
        group_id = bulk_op["operationGroupId"]
        bulk_op_name = bulk_op["name"]
        if "error" in bulk_op:
            error = bulk_op["error"]["errors"][0]
            group_nodes = to_hostlist(grouped_nodes[group])
            log.warning(
                f"bulkInsert operation errors: {error['code']} name={bulk_op_name} operationGroupId={group_id} nodes={group_nodes}"
            )
        successful_inserts, failed_inserts = separate(
            lambda op: "error" in op, get_insert_operations(group_id)
        )
        # Apparently multiple errors are possible... so join with +.
        by_error_inserts = util.groupby_unsorted(
            failed_inserts,
            lambda op: "+".join(err["code"] for err in op["error"]["errors"]),
        )
        for code, failed_ops in by_error_inserts:
            failed_nodes = {trim_self_link(op["targetLink"]): op for op in failed_ops}
            hostlist = util.to_hostlist(failed_nodes)
            count = len(failed_nodes)
            log.error(
                f"{count} instances failed to start: {code} ({hostlist}) operationGroupId={group_id}"
            )
            if code != "RESOURCE_ALREADY_EXISTS":
                down_nodes(hostlist, code)
            failed_node, failed_op = next(iter(failed_nodes.items()))
            msg = "; ".join(
                f"{err['code']}: {err['message'] if 'message' in err else 'no message'}"
                for err in failed_op["error"]["errors"]
            )
            log.error(
                f"errors from insert for node '{failed_node}' ({failed_op['name']}): {msg}"
            )

        ready_nodes = {trim_self_link(op["targetLink"]) for op in successful_inserts}
        if len(ready_nodes) > 0:
            ready_nodelist = to_hostlist(ready_nodes)
            log.info(f"created {len(ready_nodes)} instances: nodes={ready_nodelist}")
            all_successful_inserts.extend(successful_inserts)

    # If reconfigure enabled, create subscriptions for successfully started instances
    if lkp.cfg.enable_reconfigure and len(all_successful_inserts):
        started_nodes = [
            parse_self_link(op["targetLink"]).instance for op in successful_inserts
        ]
        count = len(started_nodes)
        hostlist = util.to_hostlist(started_nodes)
        log.info("create {} subscriptions ({})".format(count, hostlist))
        execute_with_futures(subscription_create, nodelist)


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
    request = util.compute.resourcePolicies().insert(
        project=cfg.project, region=region, body=config
    )
    log_api_request(request)
    return request


def create_placement_groups(job_id, node_list, partition_name):
    PLACEMENT_MAX_CNT = 150
    groups = {
        f"{cfg.slurm_cluster_name}-{partition_name}-{job_id}-{i}": nodes
        for i, nodes in enumerate(chunked(node_list, n=PLACEMENT_MAX_CNT))
    }
    reverse_groups = {node: group for group, nodes in groups.items() for node in nodes}

    model = next(iter(node_list))
    region = lkp.node_region(model)

    if log.isEnabledFor(logging.DEBUG):
        debug_groups = {group: to_hostlist(nodes) for group, nodes in groups.items()}
        log.debug(
            f"creating {len(groups)} placement groups: \n{yaml.safe_dump(debug_groups).rstrip()}"
        )
    requests = {
        group: create_placement_request(group, region)
        for group, incl_nodes in groups.items()
    }
    done, failed = batch_execute(requests)
    if failed:
        reqs = [f"{e}" for _, e in failed.values()]
        # delete any placement groups that managed to be created.
        delete_placement_groups(job_id, region, partition_name)
        log.fatal("failed to create placement policies: {}".format("; ".join(reqs)))
        exit(1)
    log.info(f"created {len(done)} placement groups ({to_hostlist(done.keys())})")
    return reverse_groups


def valid_placement_nodes(job_id, nodelist):
    machine_types = {
        lkp.node_prefix(node): lkp.node_template_info(node).machineType
        for node in nodelist
    }
    fail = False
    valid_types = ["c2", "c2d", "a2"]
    for prefix, machine_type in machine_types.items():
        if machine_type.split("-")[0] not in valid_types:
            log.error(f"Unsupported machine type for placement policy: {machine_type}.")
            fail = True
    if fail:
        log.error(
            f"Please use a valid machine type with placement policy: ({','.join(valid_types)})"
        )
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
    if job_id is None:
        log.debug(f"ResumeProgram {nodelist}")
    else:
        log.debug(f"PrologSlurmctld exclusive resume {nodelist} {job_id}")
    # nodes are split between normal and exclusive
    # exclusive nodes are handled by PrologSlurmctld
    nodes = expand_nodelist(nodelist)

    # Filter out nodes not in config.yaml
    cloud_nodes, local_nodes = lkp.filter_nodes(nodes)
    if len(local_nodes) > 0:
        log.debug(
            f"Ignoring local nodes '{util.to_hostlist(local_nodes)}' from '{nodelist}'"
        )
    if len(cloud_nodes) > 0:
        log.debug(
            f"Using cloud nodes '{util.to_hostlist(cloud_nodes)}' from '{nodelist}'"
        )
    else:
        log.debug("No cloud nodes to resume")
        return
    nodes = cloud_nodes

    if force:
        exclusive = normal = nodes
        prelog = "force "
    else:
        normal, exclusive = separate(is_exclusive_node, nodes)
        prelog = ""
    if job_id is None or force:
        if len(normal) > 0:
            hostlist = util.to_hostlist(normal)
            log.info(f"{prelog}resume {hostlist}")
            resume_nodes(normal)
    else:
        if len(exclusive) > 0:
            hostlist = util.to_hostlist(exclusive)
            log.info(f"{prelog}exclusive resume {hostlist} {job_id}")
            prolog_resume_nodes(job_id, exclusive)
        else:
            log.debug("No exclusive nodes to resume")


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
    "--debug",
    "-d",
    dest="loglevel",
    action="store_const",
    const=logging.DEBUG,
    default=logging.INFO,
    help="Enable debugging output",
)
parser.add_argument(
    "--trace-api",
    "-t",
    action="store_true",
    help="Enable detailed api request output",
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

    if cfg.enable_debug_logging:
        args.loglevel = logging.DEBUG
    if args.trace_api:
        cfg.extra_logging_flags = list(cfg.extra_logging_flags)
        cfg.extra_logging_flags.append("trace_api")
    util.chown_slurm(LOGFILE, mode=0o600)
    util.config_root_logger(filename, level=args.loglevel, logfile=LOGFILE)
    sys.excepthook = util.handle_exception

    main(args.nodelist, args.job_id, args.force)
