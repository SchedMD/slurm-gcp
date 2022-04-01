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

from addict import Dict as NSDict

import util
from util import (
    execute_with_futures,
    run,
    batch_execute,
    ensure_execute,
    subscription_delete,
    wait_for_operations,
)
from util import seperate, split_nodelist, is_exclusive_node
from util import lkp, cfg, compute


filename = Path(__file__).name
LOGFILE = (Path(cfg.slurm_log_dir if cfg else ".") / filename).with_suffix(".log")
log = logging.getLogger(filename)

TOT_REQ_CNT = 1000


def truncate_iter(iterable, max_count):
    end = "..."
    _iter = iter(iterable)
    for i, el in enumerate(_iter, start=1):
        if i >= max_count:
            yield end
            break
        yield el


def delete_instance_request(instance, project=None, zone=None):
    project = project or lkp.project
    return compute.instances().delete(
        project=project,
        zone=(zone or lkp.instance(instance).zone),
        instance=instance,
    )


def delete_instances(instances):
    """Call regionInstances.bulkInsert to create instances"""
    if len(instances) == 0:
        return
    invalid, valid = seperate(lambda inst: bool(lkp.instance(inst)), instances)
    log.debug("instances do not exist: {}".format(",".join(invalid)))

    if lkp.cfg.enable_reconfigure:
        count = len(instances)
        hostlist = util.to_hostlist(instances)
        log.info("delete {} subscriptions ({})".format(count, hostlist))
        execute_with_futures(subscription_delete, instances)

    requests = {inst: delete_instance_request(inst) for inst in valid}
    done, failed = batch_execute(requests)
    if failed:
        failed_nodes = [f"{n}: {e}" for n, (_, e) in failed.items()]
        node_str = "\n".join(str(el) for el in truncate_iter(failed_nodes, 5))
        log.error(f"some nodes failed to delete: {node_str}")
    wait_for_operations(done.values())


def expand_nodelist(nodelist):
    """expand nodes in hostlist to hostnames"""
    nodes = run(f"{lkp.scontrol} show hostnames {nodelist}").stdout.splitlines()
    return nodes


def suspend_nodes(nodelist):
    """suspend nodes in nodelist"""
    nodes = nodelist
    if not isinstance(nodes, list):
        nodes = expand_nodelist(nodes)
    delete_instances(nodes)


def delete_placement_groups(job_id, region, partition_name):
    def delete_placement_request(pg_name):
        return compute.resourcePolicies().delete(
            project=cfg.project, region=region, resourcePolicy=pg_name
        )

    flt = f"name={cfg.slurm_cluster_name}-{partition_name}-{job_id}-*"
    req = compute.resourcePolicies().list(
        project=cfg.project, region=region, filter=flt
    )
    result = ensure_execute(req).get("items")
    if not result:
        log.debug(f"No placement groups found to delete for job id {job_id}")
        return
    requests = {pg["name"]: delete_placement_request(pg["name"]) for pg in result}
    done, failed = batch_execute(requests)
    if failed:
        failed_pg = [f"{n}: {e}" for n, (_, e) in failed.items()]
        log.error(f"some nodes failed to delete: {failed_pg}")


def epilog_suspend_nodes(nodelist, job_id):
    """epilog suspend"""
    nodes = nodelist
    if not isinstance(nodes, list):
        nodes = expand_nodelist(nodes)
    if any(not is_exclusive_node(node) for node in nodes):
        log.fatal(f"nodelist includes non-exclusive nodes: {nodelist}")
    # Mark nodes as off limits to new jobs while powering down.
    # Have to use "down" because it's the only, current, way to remove the
    # power_up flag from the node -- followed by a power_down -- if the
    # PrologSlurmctld fails with a non-zero exit code.
    run(
        f"{lkp.scontrol} update node={','.join(nodelist)} state=down reason='{job_id} finishing'"
    )
    # Power down nodes in slurm, so that they will become available again.
    run(f"{lkp.scontrol} update node={','.join(nodelist)} state=power_down")

    model = next(iter(nodes))
    region = lkp.node_region(model)
    partition = lkp.node_partition(model)
    suspend_nodes(nodelist)
    if partition.enable_placement_groups:
        delete_placement_groups(job_id, region, partition.partition_name)


def main(nodelist, job_id, force=False):
    """main called when run as script"""
    log.debug(f"main {nodelist} {job_id}")
    if force:
        suspend_nodes(nodelist)
    nodes = expand_nodelist(nodelist)
    normal, exclusive = seperate(is_exclusive_node, nodes)
    if job_id is not None:
        if exclusive:
            log.info(f"epilog suspend {exclusive} job_id={job_id}")
            epilog_suspend_nodes(exclusive, job_id)
    else:
        if normal:
            log.info(f"suspend {normal}")
            suspend_nodes(normal)


parser = argparse.ArgumentParser(
    description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
)
parser.add_argument("nodelist", help="list of nodes to suspend")
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
    log = logging.getLogger(Path(__file__).name)
    sys.excepthook = util.handle_exception

    main(args.nodelist, args.job_id, args.force)
