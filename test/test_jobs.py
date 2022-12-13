import logging

# from hostlist import expand_hostlist as expand
from testutils import (
    wait_job_state,
    sbatch,
    get_file,
)

logging.basicConfig(level=logging.INFO)
log = logging.getLogger()


def test_small_job(cluster):
    job_id = sbatch(cluster, "sbatch -N1 --wrap='srun hostname'")
    job = wait_job_state(cluster, job_id, "COMPLETED", "FAILED", "CANCELLED")
    assert job["job_state"] == "COMPLETED"


def test_job(cluster):
    job_id = sbatch(cluster, "sbatch -N2 --wrap='srun hostname'")
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
    cluster.login_exec("module load openmpi; mpicc -o hello hello.c")
    job_id = sbatch(cluster, "module load openmpi; sbatch -N3 --wrap='srun hello'")
    job = wait_job_state(cluster, job_id, "COMPLETED", "FAILED", "CANCELLED")
    log.info(get_file(cluster, f"slurm-{job_id}.out"))
    assert job["job_state"] == "COMPLETED"


# def test_partitions(cluster, config_partitions, cluster_partitions):
#     # The same partition names (keys) should be in config and cluster
#     assert set(config_partitions) == set(cluster_partitions)

#     for name, part in cluster_partitions.items():
#         config = config_partitions[name]
#         nodelist = expand(part.nodes, sort=True)
#         assert len(nodelist) == config['max_node_count']


# def test_gpu_config(cluster, config_partitions, cluster_partitions):
#    for name, config in config_partitions.items():
#        if config["gpu_count"] == 0:
#            continue
#        part = cluster_partitions[name]
#        nodename = expand(part.nodes)[0]
#        node = cluster.api.slurmctld_get_node(nodename).nodes[0]
#        count = next(g for g in node.gres.split(",") if g.startswith("gpu")).split(":")[
#            1
#        ]
#        assert int(count) == config["gpu_count"]


# def test_network_mounts(cluster):
#    """test cluster-wide and login network storage
#    Ignores partition-only network storage for now
#    """
#    get_mounts = (
#        "df -h --output=source,target -t nfs4 -t lustre -t gcsfuse -t cfs "
#        "| awk '{if (NR!=1) {print $1 \" \" $2}}'"
#    )
#
#    def parse_mounts(df):
#        return {tuple(mount.split(" ")) for mount in df.splitlines()}
#
#    login_mounts = parse_mounts(cluster.login_exec_output(get_mounts))
#
#    # TODO might not work for gcsfuse
#    network_storage = {
#        (f"{cluster.controller_name}:/home", "/home"),
#        (f"{cluster.controller_name}:/usr/local/etc/slurm", "/usr/local/etc/slurm"),
#        (f"{cluster.controller_name}:/etc/munge", "/etc/munge"),
#        (f"{cluster.controller_name}:/apps", "/apps"),
#    }
#    network_storage.update(
#        {
#            (
#                "{}:{}".format(
#                    cluster.controller_name
#                    if e["server_ip"] == "$controller"
#                    else e["server_ip"],
#                    e["remote_mount"],
#                ),
#                e["local_mount"],
#            )
#            for e in chain(
#                cluster.config["network_storage"],
#                cluster.config["login_network_storage"],
#            )
#        }
#    )
#
#    assert network_storage == login_mounts


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
#
#
# def test_gpu_job(cluster):
#    part = next(
#        (
#            p
#            for p in cluster.partitions()
#            if any(pn for pn in p["partition_nodes"].values())
#        ),
#        None,
#    )
#    if part is None:
#        return
#    job_id = sbatch(
#        cluster, f"sbatch --partition={part['name']} --gpus=2 --wrap='srun nvidia-smi'"
#    )
#    job = wait_job_state(cluster, job_id, "COMPLETED", "FAILED", "CANCELLED")
#    assert job["job_state"] == "COMPLETED"
#    log.info(get_file(cluster, f"slurm-{job_id}.out"))


# def test_preemption(cluster):
#    part = next(
#        (p for p in config_partitions.values() if p["preemptible_bursting"]), None
#    )
#    if part is None:
#        return
#    job_id = sbatch(
#        cluster, f"sbatch -N2 --partition={part['name']} --wrap='srun sleep 9999'"
#    )
#    job = wait_job_state(cluster, job_id, "RUNNING")
#    assert job["job_state"] == "RUNNING"
#    last_node = expand(job.nodes)[-1]
#
#    run(f"gcloud compute instances stop {last_node}")
#    node = wait_node_state(cluster, last_node, "down")
#    assert node.reason == "Instance stopped/deleted"
#    wait_node_state(cluster, last_node, "idle")
#    cluster.login_exec(f"scancel {job_id}")
#    wait_job_state(cluster, job_id, "CANCELLED")
