import logging

import pytest

from hostlist import expand_hostlist as expand
from deploy import Cluster
from testutils import (
    wait_job_state,
    wait_node_state,
    wait_node_flags_any,
    sbatch,
    run,
    util,
)
from util import Lookup

log = logging.getLogger()


def test_job(cluster):
    job_id = sbatch(cluster, "sbatch -N3 --wrap='srun hostname'")
    job = wait_job_state(cluster, job_id, "COMPLETED", "FAILED", "CANCELLED")
    assert job["job_state"] == "COMPLETED"


def test_openmpi(cluster):
    prog = r"""
#include <stdio.h>
#include <mpi.h>

int main(int argc, char **argv)
{
   int node;

   MPI_Init(&argc, &argv);
   MPI_Comm_rank(MPI_COMM_WORLD, &node);

   printf("Hello World from Node %d\n", node);

   MPI_Finalize();
}
"""
    cluster.login_exec("tee hello.c", input=prog)
    cluster.login_exec(
        "bash --login -c 'module load openmpi && mpicc -o hello hello.c'"
    )
    job_id = sbatch(cluster, "sbatch -N3 --wrap='srun hello'")
    job = wait_job_state(cluster, job_id, "COMPLETED", "FAILED", "CANCELLED")
    log.info(cluster.login_get_file(f"slurm-{job_id}.out"))
    assert job["job_state"] == "COMPLETED"


def test_gpu_job(cluster, lkp):
    gpu_parts = {}
    for part_name, partition in lkp.cfg.partitions.items():
        for nodeset_name in partition.partition_nodeset:
            nodeset = lkp.cfg.nodeset.get(nodeset_name)
            template = lkp.template_info(nodeset.instance_template)
            if (
                template.gpu_count > 0
                and not template.shieldedInstanceConfig.enableSecureBoot
            ):
                gpu_parts[part_name] = partition
    if not gpu_parts:
        pytest.skip("no gpu partitions found")
        return

    for part_name, partition in gpu_parts.items():
        job_id = sbatch(
            cluster,
            f"sbatch --partition={part_name} --gpus=1 --wrap='srun nvidia-smi'",
        )
        job = wait_job_state(cluster, job_id, "COMPLETED", "FAILED", "CANCELLED")
        assert job["job_state"] == "COMPLETED"
        log.info(cluster.login_exec_output(f"cat slurm-{job_id}.out"))


def test_shielded(image_marker, cluster: Cluster, lkp: Lookup):
    # only run test for ubuntu-2004
    log.info(f"detected image_marker:{image_marker}")
    if image_marker == "debian-11-arm64":
        pytest.skip("shielded not supported on {image_marker}")
    skip_gpus = "ubuntu-2004" not in image_marker

    shielded_parts = {}
    for part_name, partition in lkp.cfg.partitions.items():
        has_gpus = any(
            lkp.template_info(
                lkp.cfg.nodeset.get(nodeset_name).instance_template
            ).gpu_count
            > 0
            for nodeset_name in partition.partition_nodeset
        )
        if skip_gpus and has_gpus:
            continue
        for nodeset_name in partition.partition_nodeset:
            nodeset = lkp.cfg.nodeset.get(nodeset_name)
            template = lkp.template_info(nodeset.instance_template)
            if template.shieldedInstanceConfig.enableSecureBoot:
                shielded_parts[part_name] = partition
                partition.has_gpus = has_gpus
    if not shielded_parts:
        pytest.skip("No viable partitions with shielded instances found")
        return

    for part_name, partition in shielded_parts.items():
        if partition.has_gpus:
            job_id = sbatch(
                cluster,
                f"sbatch --partition={part_name} --gpus=1 --wrap='srun nvidia-smi'",
            )
        else:
            job_id = sbatch(
                cluster,
                f"sbatch --partition={part_name} --wrap='srun hostname'",
            )
        job = wait_job_state(cluster, job_id, "COMPLETED", "FAILED", "CANCELLED")
        assert job["job_state"] == "COMPLETED"
        log.info(cluster.login_exec_output(f"cat slurm-{job_id}.out"))


def test_placement_groups(cluster, lkp):
    nodesets = []
    for nodeset_name, nodeset in lkp.cfg.nodeset.items():
        if nodeset.enable_placement:
            nodesets.append(nodeset_name)
    partitions = []
    for part_name, partition in lkp.cfg.partitions.items():
        if any(item in nodesets for item in partition.partition_nodeset):
            partitions.append(part_name)
    if not partitions:
        pytest.skip("no partitions with placement groups enabled")
        return

    def placement_job(part_name):
        job_id = sbatch(
            cluster, f"sbatch -N3 --partition={part_name} --wrap='sleep 600'"
        )
        job = wait_job_state(cluster, job_id, "RUNNING", max_wait=300)
        nodes = expand(job["nodes"])
        physical_hosts = {
            node: lkp.describe_instance(node).resourceStatus.physicalHost or None
            for node in nodes
        }
        # this isn't working sometimes now. None are matching
        log.debug(
            "matching physicalHost IDs: {}".format(
                set.intersection(*map(set, physical_hosts.values()))
            )
        )
        # assert bool(set.intersection(*physical_hosts))
        assert all(host is not None for node, host in physical_hosts.items())
        cluster.login_exec(f"scancel {job_id}")
        job = wait_job_state(cluster, job_id, "CANCELLED")
        for node in nodes:
            wait_node_flags_any(cluster, node, "idle", "POWERED_DOWN", max_wait=240)

    util.execute_with_futures(placement_job, partitions)


# def test_partition_jobs(cluster):
#    jobs = []
#    for name, part in cluster_partitions.items():
#        job_id = sbatch(
#            cluster, f"sbatch -N2 --partition={name} --wrap='srun hostname'"
#        )
#        jobs.append(job_id)
#    for job_id in jobs:
#        job = wait_job_state(cluster, job_id, "COMPLETED", "FAILED", "CANCELLED")
#        assert job["job_state"] == "COMPLETED"


def test_preemption(cluster: Cluster, lkp: Lookup):
    partitions = []
    for part_name, partition in lkp.cfg.partitions.items():
        for nodeset_name in partition.partition_nodeset:
            nodeset = lkp.cfg.nodeset.get(nodeset_name)
            template = lkp.template_info(nodeset.instance_template)
            if template.scheduling.preemptible:
                partitions.append(part_name)
                break

    if not partitions:
        pytest.skip("no partitions with preemptible nodes")
        return

    def preemptible_job(part_name):
        job_id = sbatch(
            cluster, f"sbatch -N2 --partition={part_name} --wrap='srun sleep 9999'"
        )
        job = wait_job_state(cluster, job_id, "RUNNING")
        last_node = expand(job["nodes"])[-1]

        lkp.instances.cache_clear()
        inst = lkp.instance(last_node)
        run(f"gcloud compute instances stop {last_node} --zone={inst.zone}")
        node = wait_node_state(cluster, last_node, "down", max_wait=180)
        assert node["reason"] == "Instance stopped/deleted"
        wait_node_state(cluster, last_node, "idle")
        cluster.login_exec(f"scancel {job_id}")
        wait_job_state(cluster, job_id, "CANCELLED")

    util.execute_with_futures(preemptible_job, partitions)


def test_prolog_scripts(cluster: Cluster, lkp: Lookup):
    """check that the prolog and epilog scripts ran"""
    # The partition this runs on must not be job exclusive so the VM stays
    # after job completion
    job_id = sbatch(cluster, "sbatch -N1 --wrap='srun sleep 999'")
    job = wait_job_state(cluster, job_id, "RUNNING", max_wait=300)
    node = next(iter(expand(job["nodes"])))

    node_ssh = cluster.ssh(lkp.instance(node).selfLink)
    check = cluster.exec_cmd(node_ssh, f"ls /slurm/out/prolog_{job_id}")
    log.debug(f"{check.command}: {check.stdout or check.stderr}")
    assert check.exit_status == 0

    cluster.login_exec(f"scancel {job_id}")
    wait_job_state(cluster, job_id, "CANCELLED", max_wait=300)

    check = cluster.exec_cmd(node_ssh, f"ls /slurm/out/epilog_{job_id}")
    log.debug(f"{check.command}: {check.stdout or check.stderr}")
    assert check.exit_status == 0
