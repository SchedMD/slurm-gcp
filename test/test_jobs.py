import logging

import pytest

from hostlist import expand_hostlist as expand
from testutils import (
    wait_until,
    wait_job_state,
    wait_node_state,
    sbatch,
    run,
    util,
)

log = logging.getLogger()


def test_small_job(cluster):
    job_id = sbatch(cluster, "sbatch -N1 --wrap='srun hostname'")
    job = wait_job_state(cluster, job_id, "COMPLETED", "FAILED", "CANCELLED")
    assert job["job_state"] == "COMPLETED"


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
        for group_name, group in partition.partition_nodes.items():
            template = lkp.template_info(group.instance_template)
            if template.gpu_count > 0:
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


def test_placement_groups(cluster, lkp):
    partitions = []
    for part_name, partition in lkp.cfg.partitions.items():
        if partition.enable_placement_groups:
            partitions.append(part_name)
    if not partitions:
        pytest.skip("no partitions with placement groups enabled")
        return

    def is_node_powered_down(node):
        info = cluster.get_node(node)
        state = info["state"]
        flags = set(info["state_flags"])
        log.info(
            f"waiting for node {node} to be powered_down; state={state} flags={','.join(flags)}"
        )
        powered_down = set(["POWERED_DOWN"])
        return state == "idle" and (powered_down & flags)

    def placement_job(part_name):
        job_id = sbatch(
            cluster, f"sbatch -N2 --partition={part_name} --wrap='sleep 600'"
        )
        job = wait_job_state(cluster, job_id, "RUNNING", max_wait=300)
        nodes = expand(job["nodes"])
        physical_hosts = [
            set(
                filter(
                    None,
                    lkp.describe_instance(node).resourceStatus.physicalHost.split("/"),
                )
            )
            for node in nodes
        ]
        assert bool(set.intersection(*physical_hosts))
        cluster.login_exec(f"scancel {job_id}")
        job = wait_job_state(cluster, job_id, "CANCELLED")
        for node in nodes:
            assert wait_until(is_node_powered_down, node, max_wait=240)

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


def test_preemption(cluster, lkp):
    partitions = []
    for part_name, partition in lkp.cfg.partitions.items():
        for group_name, group in partition.partition_nodes.items():
            if group.enable_spot_vm:
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
        assert job["job_state"] == "RUNNING"
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
