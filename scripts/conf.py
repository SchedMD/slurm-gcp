#!/usr/bin/env python3

# Copyright (C) SchedMD LLC.
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

from addict import Dict as NSDict
from collections import defaultdict
import json
from pathlib import Path
import util
from util import lkp, dirs, cfg, slurmdirs
from util import (
    access_secret_version,
    project_metadata,
)


FILE_PREAMBLE = """
# Warning:
# This file is managed by a script. Manual modifications will be overwritten.
"""


def dict_to_conf(conf, delim=" "):
    """convert dict to delimited slurm-style key-value pairs"""

    def filter_conf(pair):
        k, v = pair
        if isinstance(v, list):
            v = ",".join(el for el in v if el is not None)
        return k, (v if bool(v) or v == 0 else None)

    return delim.join(
        f"{k}={v}" for k, v in map(filter_conf, conf.items()) if v is not None
    )


def conflines(cloud_parameters, lkp=lkp):
    scripts_dir = lkp.cfg.get("install_dir", dirs.scripts)
    no_comma_params = cloud_parameters.get("no_comma_params", False)

    any_gpus = any(
        lkp.template_info(node.instance_template).gpu_count > 0
        for part in cfg.partitions.values()
        for node in part.partition_nodes.values()
    )

    any_dynamic = any(bool(p.partition_feature) for p in lkp.cfg.partitions.values())
    comma_params = {
        "PrivateData": [
            "cloud",
        ],
        "LaunchParameters": [
            "enable_nss_slurm",
            "use_interactive_step",
        ],
        "SlurmctldParameters": [
            "cloud_reg_addrs" if any_dynamic else "cloud_dns",
            "enable_configless",
            "idle_on_node_suspend",
        ],
        "SchedulerParameters": [
            "bf_continue",
            "salloc_wait_nodes",
        ],
        "CommunicationParameters": [
            "NoAddrCache",
        ],
        "GresTypes": [
            "gpu" if any_gpus else None,
        ],
    }
    prolog_path = Path(dirs.custom_scripts / "prolog.d")
    epilog_path = Path(dirs.custom_scripts / "epilog.d")
    prolog_path.mkdir(exist_ok=True)
    epilog_path.mkdir(exist_ok=True)
    any_exclusive = any(
        bool(p.enable_job_exclusive) for p in lkp.cfg.partitions.values()
    )
    conf_options = {
        **(comma_params if not no_comma_params else {}),
        "Prolog": f"{prolog_path}/*" if lkp.cfg.prolog_scripts else None,
        "Epilog": f"{epilog_path}/*" if lkp.cfg.epilog_scripts else None,
        "PrologSlurmctld": f"{scripts_dir}/resume.py" if any_exclusive else None,
        "EpilogSlurmctld": f"{scripts_dir}/suspend.py" if any_exclusive else None,
        "SuspendProgram": f"{scripts_dir}/suspend.py",
        "ResumeProgram": f"{scripts_dir}/resume.py",
        "ResumeFailProgram": f"{scripts_dir}/suspend.py",
        "ResumeRate": cloud_parameters.get("resume_rate", 0),
        "ResumeTimeout": cloud_parameters.get("resume_timeout", 300),
        "SuspendRate": cloud_parameters.get("suspend_rate", 0),
        "SuspendTimeout": cloud_parameters.get("suspend_timeout", 300),
        "TreeWidth": "65533" if any_dynamic else None,
    }
    return dict_to_conf(conf_options, delim="\n")


def node_group_lines(node_group, part_name, lkp=lkp):
    template_info = lkp.template_info(node_group.instance_template)
    machine_conf = lkp.template_machine_conf(node_group.instance_template)

    node_def = dict_to_conf(
        {
            "NodeName": "DEFAULT",
            "State": "UNKNOWN",
            "RealMemory": machine_conf.memory,
            "Boards": machine_conf.boards,
            "Sockets": machine_conf.sockets,
            "CoresPerSocket": machine_conf.cores_per_socket,
            "ThreadsPerCore": machine_conf.threads_per_core,
            "CPUs": machine_conf.cpus,
            **node_group.node_conf,
        }
    )

    gres = None
    if template_info.gpu_count:
        gres = f"gpu:{template_info.gpu_count}"

    lines = [node_def]
    static, dynamic = lkp.nodeset_lists(node_group, part_name)
    nodeset = lkp.nodeset_prefix(node_group.group_name, part_name)
    if static:
        lines.append(
            dict_to_conf(
                {
                    "NodeName": static,
                    "State": "CLOUD",
                    "Gres": gres,
                }
            )
        )
    if dynamic:
        lines.append(
            dict_to_conf(
                {
                    "NodeName": dynamic,
                    "State": "CLOUD",
                    "Gres": gres,
                }
            )
        )
    lines.append(
        dict_to_conf(
            {"NodeSet": nodeset, "Nodes": ",".join(filter(None, (static, dynamic)))}
        )
    )

    return (nodeset, "\n".join(filter(None, lines)))


def partitionlines(partition, lkp=lkp):
    """Make a partition line for the slurm.conf"""
    part_name = partition.partition_name
    lines = []
    has_nodes: bool = False
    has_feature: bool = False
    defmem: int = 0
    nodesets: list = []

    if len(partition.partition_nodes.values()) > 0:
        group_lines = [
            node_group_lines(group, part_name, lkp)
            for group in partition.partition_nodes.values()
        ]
        nodesets, nodelines = zip(*group_lines)

        def defmempercpu(template_link):
            machine_conf = lkp.template_machine_conf(template_link)
            return max(100, machine_conf.memory // machine_conf.cpus)

        defmem = min(
            defmempercpu(node.instance_template)
            for node in partition.partition_nodes.values()
        )
        lines.extend(nodelines)
        has_nodes = True
    if partition.partition_feature:
        nodelines = [
            dict_to_conf({"NodeSet": part_name, "Feature": partition.partition_feature})
        ]
        lines.extend(nodelines)
        has_feature = True
    if has_nodes or has_feature:
        nodes = []
        if has_nodes:
            nodes.extend(nodesets)
        if has_feature:
            nodes.append(part_name)
        line_elements = {
            "PartitionName": part_name,
            "Nodes": ",".join(nodes),
            "State": "UP",
            "DefMemPerCPU": defmem,
            "SuspendTime": 300,
            "Oversubscribe": "Exclusive" if partition.enable_job_exclusive else None,
            "PowerDownOnIdle": "YES" if partition.enable_job_exclusive else None,
            **partition.partition_conf,
        }
        lines.extend([dict_to_conf(line_elements)])

    return "\n".join(lines)


def make_cloud_conf(lkp=lkp, cloud_parameters=None):
    """generate cloud.conf snippet"""
    if cloud_parameters is None:
        cloud_parameters = lkp.cfg.cloud_parameters

    static_nodes = ",".join(lkp.static_nodelist())
    suspend_exc = (
        dict_to_conf(
            {
                "SuspendExcNodes": static_nodes,
            }
        )
        if static_nodes
        else None
    )

    lines = [
        FILE_PREAMBLE,
        conflines(cloud_parameters),
        *(partitionlines(p, lkp) for p in lkp.cfg.partitions.values()),
        suspend_exc,
        "\n",
    ]
    return "\n\n".join(filter(None, lines))


def gen_cloud_conf(lkp=lkp, cloud_parameters=None):
    content = make_cloud_conf(lkp, cloud_parameters=cloud_parameters)

    conf_file = Path(lkp.cfg.output_dir or slurmdirs.etc) / "cloud.conf"
    conf_file.write_text(content)
    util.chown_slurm(conf_file, mode=0o644)


def install_slurm_conf(lkp=lkp):
    """install slurm.conf"""
    if lkp.cfg.ompi_version:
        mpi_default = "pmi2"
    else:
        mpi_default = "none"

    conf_options = {
        "name": lkp.cfg.slurm_cluster_name,
        "control_addr": lkp.control_addr if lkp.control_addr else lkp.hostname_fqdn,
        "control_host": lkp.control_host,
        "control_host_port": lkp.control_host_port,
        "scripts": dirs.scripts,
        "slurmlog": dirs.log,
        "state_save": slurmdirs.state,
        "mpi_default": mpi_default,
    }
    conf_resp = project_metadata(f"{cfg.slurm_cluster_name}-slurm-tpl-slurm-conf")
    conf = conf_resp.format(**conf_options)

    conf_file = Path(lkp.cfg.output_dir or slurmdirs.etc) / "slurm.conf"
    conf_file.write_text(conf)
    util.chown_slurm(conf_file, mode=0o644)


def install_slurmdbd_conf(lkp=lkp):
    """install slurmdbd.conf"""
    conf_options = NSDict(
        {
            "control_host": lkp.control_host,
            "slurmlog": dirs.log,
            "state_save": slurmdirs.state,
            "db_name": "slurm_acct_db",
            "db_user": "slurm",
            "db_pass": '""',
            "db_host": "localhost",
            "db_port": "3306",
        }
    )
    if lkp.cfg.cloudsql:
        secret_name = f"{cfg.slurm_cluster_name}-slurm-secret-cloudsql"
        payload = json.loads(access_secret_version(util.project, secret_name))

        if payload["db_name"] and payload["db_name"] != "":
            conf_options.db_name = payload["db_name"]
        if payload["user"] and payload["user"] != "":
            conf_options.db_user = payload["user"]
        if payload["password"] and payload["password"] != "":
            conf_options.db_pass = payload["password"]

        db_host_str = payload["server_ip"].split(":")
        if db_host_str[0] and db_host_str[0] != "":
            conf_options.db_host = db_host_str[0]
            conf_options.db_port = db_host_str[1] if len(db_host_str) >= 2 else "3306"

    conf_resp = project_metadata(f"{cfg.slurm_cluster_name}-slurm-tpl-slurmdbd-conf")
    conf = conf_resp.format(**conf_options)

    conf_file = Path(lkp.cfg.output_dir or slurmdirs.etc) / "slurmdbd.conf"
    conf_file.write_text(conf)
    util.chown_slurm(conf_file, 0o600)


def install_cgroup_conf(lkp=lkp):
    """install cgroup.conf"""
    conf = project_metadata(f"{cfg.slurm_cluster_name}-slurm-tpl-cgroup-conf")

    conf_file = Path(lkp.cfg.output_dir or slurmdirs.etc) / "cgroup.conf"
    conf_file.write_text(conf)
    util.chown_slurm(conf_file, mode=0o600)


def gen_cloud_gres_conf(lkp=lkp):
    """generate cloud_gres.conf"""

    gpu_nodes = defaultdict(list)
    for part_name, partition in lkp.cfg.partitions.items():
        if len(partition.partition_nodes.values()) > 0:
            for node in partition.partition_nodes.values():
                template_info = lkp.template_info(node.instance_template)
                gpu_count = template_info.gpu_count
                if gpu_count == 0:
                    continue
                gpu_nodes[gpu_count].extend(
                    filter(None, lkp.nodeset_lists(node, part_name))
                )

    lines = [
        dict_to_conf(
            {
                "NodeName": names,
                "Name": "gpu",
                "File": "/dev/nvidia{}".format(f"[0-{i-1}]" if i > 1 else "0"),
            }
        )
        for i, names in gpu_nodes.items()
    ]
    lines.append("\n")
    content = FILE_PREAMBLE + "\n".join(lines)

    conf_file = Path(lkp.cfg.output_dir or slurmdirs.etc) / "cloud_gres.conf"
    conf_file.write_text(content)
    util.chown_slurm(conf_file, mode=0o600)


def install_gres_conf(lkp=lkp):
    conf_file = Path(lkp.cfg.output_dir or slurmdirs.etc) / "cloud_gres.conf"
    gres_conf = Path(lkp.cfg.output_dir or slurmdirs.etc) / "gres.conf"
    if not gres_conf.exists():
        gres_conf.symlink_to(conf_file)
    util.chown_slurm(gres_conf, mode=0o600)
