import logging

import pytest

# from hostlist import expand_hostlist as expand
# from testutils import (
#    wait_job_state,
#    sbatch,
#    get_file,
# )

log = logging.getLogger()


def test_gpu_config(cluster, lkp):
    gpu_groups = {}
    for part_name, partition in lkp.cfg.partitions.items():
        for group_name, group in partition.partition_nodes.items():
            template = lkp.template_info(group.instance_template)
            if template.gpu_count > 0:
                gpu_groups[lkp.nodeset_prefix(group_name, part_name)] = template
    if not gpu_groups:
        pytest.skip("no gpu partitions found")
        return

    for prefix, template in gpu_groups.items():
        node = cluster.get_node(f"{prefix}-0")
        count = next(g for g in node["gres"].split(",") if g.startswith("gpu")).split(
            ":"
        )[1]
        assert int(count) == template.gpu_count


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


# def test_partitions(cluster, config_partitions, cluster_partitions):
#     # The same partition names (keys) should be in config and cluster
#     assert set(config_partitions) == set(cluster_partitions)

#     for name, part in cluster_partitions.items():
#         config = config_partitions[name]
#         nodelist = expand(part.nodes, sort=True)
#         assert len(nodelist) == config['max_node_count']
