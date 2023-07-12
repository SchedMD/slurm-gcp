import logging
import hostlist

from itertools import chain
import pytest

from deploy import Cluster
from hostlist import expand_hostlist as expand
from testutils import (
    wait_node_flags_any,
    wait_until,
    wait_job_state,
    sbatch,
    util,
)
from util import Lookup


log = logging.getLogger()


def test_static(cluster: Cluster, lkp: util.Lookup):
    power_states = set(
        (
            "POWERING_DOWN",
            "POWERED_DOWN",
            "POWERING_UP",
        )
    )

    def is_node_up(node):
        info = cluster.get_node(node)
        state, *flags = info["state"]
        state = state.lower()
        flags = set(flags)
        log.info(
            f"waiting for static node {node} to be up; state={state} flags={','.join(flags)}"
        )
        return state == "idle" and not (power_states & flags)

    for node in chain.from_iterable(
        hostlist.expand_hostlist(nodes) for nodes in lkp.static_nodelist()
    ):
        assert wait_until(is_node_up, node)


def test_compute_startup_scripts(cluster: Cluster, lkp: Lookup):
    """check that custom compute startup scripts ran on static nodes"""
    # TODO check non static too?
    for node in chain.from_iterable(
        hostlist.expand_hostlist(nodes) for nodes in lkp.static_nodelist()
    ):
        node_ssh = cluster.ssh(lkp.instance(node).selfLink)
        check = cluster.exec_cmd(node_ssh, "ls /slurm/out/compute")
        log.debug(f"{check.command}: {check.stdout or check.stderr}")
        assert check.exit_status == 0


def test_exclusive_labels(cluster: Cluster, lkp: util.Lookup):
    partitions = []
    for part_name, partition in lkp.cfg.partitions.items():
        if partition.enable_job_exclusive:
            partitions.append(part_name)
    if not partitions:
        pytest.skip("no partitions with enable_job_exclusive")
        return

    def check_node_labels(partition):
        job_id = sbatch(
            cluster, f"sbatch -N2 --partition={partition} --wrap='sleep 600'"
        )
        job = wait_job_state(cluster, job_id, "RUNNING", max_wait=300)
        nodes = expand(job["nodes"])

        node_labels = [lkp.describe_instance(node).labels for node in nodes]
        assert all(
            "slurm_job_id" in labels and int(labels.slurm_job_id) == job_id
            for labels in node_labels
        )

        cluster.login_exec(f"scancel {job_id}")
        job = wait_job_state(cluster, job_id, "CANCELLED")
        for node in nodes:
            wait_node_flags_any(cluster, node, "idle", "POWERED_DOWN")

    util.execute_with_futures(check_node_labels, partitions)
