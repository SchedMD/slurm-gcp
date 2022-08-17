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

import json
import logging
import os
import re
import shutil
import subprocess
import sys
import stat
import time
from collections import defaultdict
from concurrent.futures import as_completed
from functools import partialmethod, lru_cache
from itertools import chain
from pathlib import Path

from addict import Dict as NSDict

import util
from util import run, instance_metadata, project_metadata, separate
from util import nodeset_prefix, nodeset_lists
from util import access_secret_version
from util import lkp, cfg, dirs, slurmdirs
import slurmsync

SETUP_SCRIPT = Path(__file__)
filename = SETUP_SCRIPT.name
LOGFILE = ((cfg.slurm_log_dir if cfg else ".") / SETUP_SCRIPT).with_suffix(".log")
log = logging.getLogger(filename)

Path.mkdirp = partialmethod(Path.mkdir, parents=True, exist_ok=True)


MOTD_HEADER = """
                                 SSSSSSS
                                SSSSSSSSS
                                SSSSSSSSS
                                SSSSSSSSS
                        SSSS     SSSSSSS     SSSS
                       SSSSSS               SSSSSS
                       SSSSSS    SSSSSSS    SSSSSS
                        SSSS    SSSSSSSSS    SSSS
                SSS             SSSSSSSSS             SSS
               SSSSS    SSSS    SSSSSSSSS    SSSS    SSSSS
                SSS    SSSSSS   SSSSSSSSS   SSSSSS    SSS
                       SSSSSS    SSSSSSS    SSSSSS
                SSS    SSSSSS               SSSSSS    SSS
               SSSSS    SSSS     SSSSSSS     SSSS    SSSSS
          S     SSS             SSSSSSSSS             SSS     S
         SSS            SSSS    SSSSSSSSS    SSSS            SSS
          S     SSS    SSSSSS   SSSSSSSSS   SSSSSS    SSS     S
               SSSSS   SSSSSS   SSSSSSSSS   SSSSSS   SSSSS
          S    SSSSS    SSSS     SSSSSSS     SSSS    SSSSS    S
    S    SSS    SSS                                   SSS    SSS    S
    S     S                                                   S     S
                SSS
                SSS
                SSS
                SSS
 SSSSSSSSSSSS   SSS   SSSS       SSSS    SSSSSSSSS   SSSSSSSSSSSSSSSSSSSS
SSSSSSSSSSSSS   SSS   SSSS       SSSS   SSSSSSSSSS  SSSSSSSSSSSSSSSSSSSSSS
SSSS            SSS   SSSS       SSSS   SSSS        SSSS     SSSS     SSSS
SSSS            SSS   SSSS       SSSS   SSSS        SSSS     SSSS     SSSS
SSSSSSSSSSSS    SSS   SSSS       SSSS   SSSS        SSSS     SSSS     SSSS
 SSSSSSSSSSSS   SSS   SSSS       SSSS   SSSS        SSSS     SSSS     SSSS
         SSSS   SSS   SSSS       SSSS   SSSS        SSSS     SSSS     SSSS
         SSSS   SSS   SSSS       SSSS   SSSS        SSSS     SSSS     SSSS
SSSSSSSSSSSSS   SSS   SSSSSSSSSSSSSSS   SSSS        SSSS     SSSS     SSSS
SSSSSSSSSSSS    SSS    SSSSSSSSSSSSS    SSSS        SSSS     SSSS     SSSS

"""


FILE_PREAMBLE = """
# Warning:
# This file is managed by a script. Manual modifications will be overwritten.
"""


def start_motd():
    """advise in motd that slurm is currently configuring"""
    wall_msg = "*** Slurm is currently being configured in the background. ***"
    motd_msg = MOTD_HEADER + wall_msg + "\n\n"
    Path("/etc/motd").write_text(motd_msg)
    util.run(f"wall -n '{wall_msg}'", timeout=30)


def end_motd(broadcast=True):
    """modify motd to signal that setup is complete"""
    Path("/etc/motd").write_text(MOTD_HEADER)

    if not broadcast:
        return

    run(
        "wall -n '*** Slurm {} setup complete ***'".format(lkp.instance_role),
        timeout=30,
    )
    if lkp.instance_role != "controller":
        run(
            """wall -n '
/home on the controller was mounted over the existing /home.
Log back in to ensure your home directory is correct.
'""",
            timeout=30,
        )


def failed_motd():
    """modify motd to signal that setup is failed"""
    wall_msg = f"*** Slurm setup failed! Please view log: {LOGFILE} ***"
    motd_msg = MOTD_HEADER + wall_msg + "\n\n"
    Path("/etc/motd").write_text(motd_msg)
    util.run(f"wall -n '{wall_msg}'", timeout=30)


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


def make_cloud_conf(lkp=lkp, cloud_parameters=None):
    """generate cloud.conf snippet"""
    if cloud_parameters is None:
        cloud_parameters = lkp.cfg.cloud_parameters

    any_gpus = any(
        lkp.template_info(node.instance_template).gpu_count > 0
        for part in cfg.partitions.values()
        for node in part.partition_nodes.values()
    )

    def conflines(cloud_parameters):
        scripts_dir = lkp.cfg.output_dir or dirs.scripts
        no_comma_params = cloud_parameters.get("no_comma_params", False)
        comma_params = {
            "PrivateData": [
                "cloud",
            ],
            "LaunchParameters": [
                "enable_nss_slurm",
                "use_interactive_step",
            ],
            "SlurmctldParameters": [
                "cloud_dns",
                "idle_on_node_suspend",
            ],
            "SchedulerParameters": [
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
        }
        return dict_to_conf(conf_options, delim="\n")

    def node_group_lines(node_group, part_name):
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
        static, dynamic = nodeset_lists(node_group, part_name)
        nodeset = nodeset_prefix(node_group, part_name)
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

    def partitionlines(partition):
        """Make a partition line for the slurm.conf"""
        part_name = partition.partition_name
        group_lines = [
            node_group_lines(group, part_name)
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
        line_elements = {
            "PartitionName": part_name,
            "Nodes": ",".join(nodesets),
            "State": "UP",
            "DefMemPerCPU": defmem,
            "SuspendTime": 300,
            "Oversubscribe": "Exclusive" if partition.enable_job_exclusive else None,
            **partition.partition_conf,
        }
        lines = [
            *nodelines,
            dict_to_conf(line_elements),
        ]
        return "\n".join(lines)

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
        *(partitionlines(p) for p in lkp.cfg.partitions.values()),
        suspend_exc,
        "\n",
    ]
    return "\n\n".join(filter(None, lines))


def gen_cloud_conf(lkp=lkp, cloud_parameters=None):
    content = make_cloud_conf(lkp, cloud_parameters=cloud_parameters)

    conf_file = Path(lkp.cfg.output_dir or slurmdirs.etc) / "cloud.conf"
    conf_file_bak = conf_file.with_suffix(".conf.bak")
    if conf_file.is_file():
        shutil.copy2(conf_file, conf_file_bak)
    conf_file.write_text(content)
    util.chown_slurm(conf_file, mode=0o644)


def install_slurm_conf(lkp):
    """install slurm.conf"""
    if lkp.cfg.ompi_version:
        mpi_default = "pmi2"
    else:
        mpi_default = "none"

    conf_options = {
        "name": lkp.cfg.slurm_cluster_name,
        "control_host": lkp.control_host,
        "scripts": dirs.scripts,
        "slurmlog": dirs.log,
        "state_save": slurmdirs.state,
        "mpi_default": mpi_default,
    }
    conf_resp = project_metadata(f"{cfg.slurm_cluster_name}-slurm-tpl-slurm-conf")
    conf = conf_resp.format(**conf_options)

    conf_file = Path(lkp.cfg.output_dir or slurmdirs.etc) / "slurm.conf"
    conf_file_bak = conf_file.with_suffix(".conf.bak")
    if conf_file.is_file():
        shutil.copy2(conf_file, conf_file_bak)
    conf_file.write_text(conf)
    util.chown_slurm(conf_file, mode=0o644)


def install_slurmdbd_conf(lkp):
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
    conf_file_bak = conf_file.with_suffix(".conf.bak")
    if conf_file.is_file():
        shutil.copy2(conf_file, conf_file_bak)
    conf_file.write_text(conf)
    util.chown_slurm(conf_file, 0o600)


def install_cgroup_conf():
    """install cgroup.conf"""
    conf = project_metadata(f"{cfg.slurm_cluster_name}-slurm-tpl-cgroup-conf")

    conf_file = Path(lkp.cfg.output_dir or slurmdirs.etc) / "cgroup.conf"
    conf_file_bak = conf_file.with_suffix(".conf.bak")
    if conf_file.is_file():
        shutil.copy2(conf_file, conf_file_bak)
    conf_file.write_text(conf)
    util.chown_slurm(conf_file, mode=0o600)


def gen_cloud_gres_conf(lkp=lkp):
    """generate cloud_gres.conf"""

    gpu_nodes = defaultdict(list)
    for part_name, partition in lkp.cfg.partitions.items():
        for node in partition.partition_nodes.values():
            template_info = lkp.template_info(node.instance_template)
            gpu_count = template_info.gpu_count
            if gpu_count == 0:
                continue
            gpu_nodes[gpu_count].extend(filter(None, nodeset_lists(node, part_name)))

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
    conf_file_bak = conf_file.with_suffix(".conf.bak")
    if conf_file.is_file():
        shutil.copy2(conf_file, conf_file_bak)
    conf_file.write_text(content)
    util.chown_slurm(conf_file, mode=0o600)


def install_gres_conf():
    conf_file = Path(lkp.cfg.output_dir or slurmdirs.etc) / "cloud_gres.conf"
    gres_conf = Path(lkp.cfg.output_dir or slurmdirs.etc) / "gres.conf"
    if not gres_conf.exists():
        gres_conf.symlink_to(conf_file)
    util.chown_slurm(gres_conf, mode=0o600)


def fetch_devel_scripts():
    """download scripts from project metadata if they are present"""

    meta_json = project_metadata(f"{cfg.slurm_cluster_name}-slurm-devel")
    if not meta_json:
        return
    metadata_devel = json.loads(meta_json)

    meta_entries = [
        ("slurmeventd.py", "slurmeventd"),
        ("resume.py", "slurm-resume"),
        ("slurmsync.py", "slurmsync"),
        ("util.py", "util-script"),
        ("setup.py", "setup-script"),
        ("startup.sh", "startup-script"),
        ("load_bq.py", "loadbq"),
    ]

    for script, name in meta_entries:
        if name not in metadata_devel:
            log.debug(f"{name} not found in project metadata, not updating")
            continue
        log.info(f"updating {script} from metadata")
        content = metadata_devel[name]
        path = (dirs.scripts / script).resolve()
        # make sure parent dir exists
        path.write_text(content)
        util.chown_slurm(path, mode=0o755)


def install_custom_scripts(clean=False):
    """download custom scripts from project metadata"""
    script_pattern = re.compile(
        rf"{cfg.slurm_cluster_name}-slurm-(?P<path>\S+)-script-(?P<name>\S+)"
    )
    metadata_keys = project_metadata("/").splitlines()

    def match_name(meta_key):
        m = script_pattern.match(meta_key)
        if not m:
            # key does not match, skip
            return None
        # returned path is `partition.d/<part_name>/<name>`
        # or `<controller/compute>.d/<name>`
        parts = m["path"].split("-")
        parts[0] += ".d"
        name, _, ext = m["name"].rpartition("_")
        name = ".".join((name, ext))
        return meta_key, Path(*parts, name)

    def filter_role(meta_entry):
        if not meta_entry:
            return False
        key, path = meta_entry
        # path is <role>.d/script.sh or partition.d/<part>/script.sh
        # role is <role> or 'partition', part is None or <part>
        role, part, *_ = chain(path.parent.parts, (None,))
        role = role[:-2]  # strip off added '.d'

        # login only needs their login scripts
        if lkp.instance_role == "login":
            suffix = instance_metadata("attributes/slurm_login_suffix")
            script_types = [f"login_{suffix}"]
            return role in script_types
        # compute needs compute, prolog, epilog, and the matching partition
        if lkp.instance_role == "compute":
            script_types = ["compute", "prolog", "epilog"]
            return role in script_types or (part and part == lkp.node_partition_name())
        # controller downloads them all for good measure
        return True

    custom_scripts = list(filter(filter_role, map(match_name, metadata_keys)))
    log.info(
        "installing custom scripts: {}".format(
            ",".join(str(path) for key, path in custom_scripts)
        )
    )

    if clean:
        path = Path(dirs.custom_scripts)
        if path.exists() and path.is_dir():
            # rm -rf custom_scripts
            shutil.rmtree(path)

    dirs.custom_scripts.mkdirp()
    for key, path in custom_scripts:
        fullpath = (dirs.custom_scripts / path).resolve()
        fullpath.parent.mkdirp()
        for par in path.parents:
            util.chown_slurm(dirs.custom_scripts / par)
        log.debug(path)
        content = project_metadata(key)
        fullpath.write_text(content)
        util.chown_slurm(fullpath, mode=0o755)


def run_custom_scripts():
    """run custom scripts based on instance_role"""
    custom_dir = dirs.custom_scripts
    if lkp.instance_role == "controller":
        # controller has all scripts, but only runs controller.d
        custom_dirs = [custom_dir / "controller.d"]
    elif lkp.instance_role == "compute":
        # compute setup with compute.d and partition.d
        custom_dirs = [custom_dir / "compute.d", custom_dir / "partition.d"]
    elif lkp.instance_role == "login":
        # login setup with only login_{suffix}.d
        suffix = instance_metadata("attributes/slurm_login_suffix")
        custom_dirs = [custom_dir / f"login_{suffix}.d"]
    else:
        # Unknown role: run nothing
        custom_dirs = []
    custom_scripts = [
        p
        for d in custom_dirs
        for p in d.rglob("*")
        if p.is_file() and not p.name.endswith(".disabled")
    ]
    print_scripts = ",".join(str(s.relative_to(custom_dir)) for s in custom_scripts)
    log.debug(f"custom scripts to run: {custom_dir}/({print_scripts})")

    try:
        for script in custom_scripts:
            log.info(f"running script {script.name}")
            result = run(str(script), timeout=300, check=False, shell=True)
            runlog = (
                f"{script.name} returncode={result.returncode}\n"
                f"stdout={result.stdout}stderr={result.stderr}"
            )
            log.info(runlog)
            result.check_returncode()
    except OSError as e:
        log.error(f"script {script} is not executable")
        raise e


def local_mounts(mountlist):
    """convert network_storage list of mounts to dict of mounts,
    local_mount as key
    """
    return {str(Path(m.local_mount).resolve()): m for m in mountlist}


@lru_cache(maxsize=None)
def resolve_network_storage(partition_name=None):
    """Combine appropriate network_storage fields to a single list"""

    if lkp.instance_role == "compute":
        partition_name = lkp.node_partition_name()
    partition = cfg.partitions[partition_name] if partition_name else None

    default_mounts = (
        slurmdirs.etc,
        dirs.munge,
        dirs.home,
        dirs.apps,
    )

    # create dict of mounts, local_mount: mount_info
    CONTROL_NFS = {
        "server_ip": lkp.control_host,
        "remote_mount": "none",
        "local_mount": "none",
        "fs_type": "nfs",
        "mount_options": "defaults,hard,intr",
    }

    # seed mounts with the default controller mounts
    mounts = (
        local_mounts(
            [
                NSDict(CONTROL_NFS, local_mount=str(path), remote_mount=str(path))
                for path in default_mounts
            ]
        )
        if not cfg.disable_default_mounts
        else {}
    )
    # On non-controller instances, entries in network_storage could overwrite
    # default exports from the controller. Be careful, of course
    mounts.update(local_mounts(cfg.network_storage))
    mounts.update(local_mounts(cfg.login_network_storage))

    if partition is not None:
        mounts.update(local_mounts(partition.network_storage))
    return list(mounts.values())


def partition_mounts(mounts):
    """partition into cluster-external and internal mounts"""

    def internal_mount(mount):
        return mount.server_ip == lkp.control_host

    return separate(internal_mount, mounts)


def setup_network_storage():
    """prepare network fs mounts and add them to fstab"""
    log.info("Set up network storage")
    # filter mounts into two dicts, cluster-internal and external mounts

    all_mounts = resolve_network_storage()
    ext_mounts, int_mounts = partition_mounts(all_mounts)
    mounts = ext_mounts
    if lkp.instance_role != "controller":
        mounts.extend(int_mounts)

    # Determine fstab entries and write them out
    fstab_entries = []
    for mount in mounts:
        local_mount = Path(mount.local_mount)
        remote_mount = mount.remote_mount
        fs_type = mount.fs_type
        server_ip = mount.server_ip
        local_mount.mkdirp()

        log.info(
            "Setting up mount ({}) {}{} to {}".format(
                fs_type,
                server_ip + ":" if fs_type != "gcsfuse" else "",
                remote_mount,
                local_mount,
            )
        )

        mount_options = mount.mount_options.split(",") if mount.mount_options else []
        if not mount_options or "_netdev" not in mount_options:
            mount_options += ["_netdev"]

        if fs_type == "gcsfuse":
            fstab_entries.append(
                "{0}   {1}     {2}     {3}     0 0".format(
                    remote_mount, local_mount, fs_type, ",".join(mount_options)
                )
            )
        else:
            fstab_entries.append(
                "{0}:{1}    {2}     {3}      {4}  0 0".format(
                    server_ip,
                    remote_mount,
                    local_mount,
                    fs_type,
                    ",".join(mount_options),
                )
            )

    fstab = Path("/etc/fstab")
    if not Path(fstab.with_suffix(".bak")).is_file():
        shutil.copy2(fstab, fstab.with_suffix(".bak"))
    shutil.copy2(fstab.with_suffix(".bak"), fstab)
    with open(fstab, "a") as f:
        f.write("\n")
        for entry in fstab_entries:
            f.write(entry)
            f.write("\n")

    mount_fstab(local_mounts(mounts))


def mount_fstab(mounts):
    """Wait on each mount, then make sure all fstab is mounted"""
    from more_executors import Executors, ExceptionRetryPolicy

    def mount_path(path):

        log.info(f"Waiting for '{path}' to be mounted...")
        try:
            run(f"mount {path}", timeout=120)
        except Exception as e:
            exc_type, _, _ = sys.exc_info()
            log.error(f"mount of path '{path}' failed: {exc_type}: {e}")
            raise e
        log.info(f"Mount point '{path}' was mounted.")

    MAX_MOUNT_TIMEOUT = 60 * 5
    future_list = []
    retry_policy = ExceptionRetryPolicy(
        max_attempts=40, exponent=1.6, sleep=1.0, max_sleep=16.0
    )
    with Executors.thread_pool().with_timeout(MAX_MOUNT_TIMEOUT).with_retry(
        retry_policy=retry_policy
    ) as exe:
        for path in mounts:
            future = exe.submit(mount_path, path)
            future_list.append(future)

        # Iterate over futures, checking for exceptions
        for future in as_completed(future_list):
            try:
                future.result()
            except Exception as e:
                raise e


def setup_nfs_exports():
    """nfs export all needed directories"""
    # The controller only needs to set up exports for cluster-internal mounts
    # switch the key to remote mount path since that is what needs exporting
    mounts = resolve_network_storage()
    # controller mounts
    _, con_mounts = partition_mounts(mounts)
    con_mounts = {m.remote_mount: m for m in mounts}
    for part in cfg.partitions:
        # get internal mounts for each partition by calling
        # prepare_network_mounts as from a node in each partition
        part_mounts = resolve_network_storage(part)
        part_mounts = {m.remote_mount: m for m in part_mounts}
        con_mounts.update(part_mounts)

    # export path if corresponding selector boolean is True
    exports = []
    for path in con_mounts:
        Path(path).mkdirp()
        run(rf"sed -i '\#{path}#d' /etc/exports", timeout=30)
        exports.append(f"{path}  *(rw,no_subtree_check,no_root_squash)")

    exportsd = Path("/etc/exports.d")
    exportsd.mkdirp()
    with (exportsd / "slurm.exports").open("w") as f:
        f.write("\n")
        f.write("\n".join(exports))
    run("exportfs -a", timeout=30)


def setup_secondary_disks():
    """Format and mount secondary disk"""
    run(
        "sudo mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb"
    )
    with open("/etc/fstab", "a") as f:
        f.write(
            "\n/dev/sdb     {0}     ext4    discard,defaults,nofail     0 2".format(
                dirs.secdisk
            )
        )


def setup_sync_cronjob():
    """Create cronjob for running slurmsync.py"""
    run("crontab -u slurm -", input=(f"*/1 * * * * {dirs.scripts}/slurmsync.py\n"))


def setup_jwt_key():
    jwt_key = Path(slurmdirs.state / "jwt_hs256.key")

    if jwt_key.exists():
        log.info("JWT key already exists. Skipping key generation.")
    else:
        run("dd if=/dev/urandom bs=32 count=1 > " + str(jwt_key), shell=True)

    util.chown_slurm(jwt_key, mode=0o400)


def setup_slurmd_cronjob():
    """Create cronjob for keeping slurmd service up"""
    run(
        "crontab -u root -",
        input=(
            "*/2 * * * * "
            "if [ `systemctl status slurmd | grep -c inactive` -gt 0 ]; then "
            "mount -a; "
            "systemctl restart munge; "
            "systemctl restart slurmd; "
            "fi\n"
        ),
        timeout=30,
    )


def setup_munge_key():
    munge_key = Path(dirs.munge / "munge.key")

    if munge_key.exists():
        log.info("Munge key already exists. Skipping key generation.")
    else:
        run("create-munge-key -f", timeout=30)

    shutil.chown(munge_key, user="munge", group="munge")
    os.chmod(munge_key, stat.S_IRUSR)
    run("systemctl restart munge", timeout=30)


def setup_nss_slurm():
    """install and configure nss_slurm"""
    # setup nss_slurm
    Path("/var/spool/slurmd").mkdirp()
    run(
        "ln -s {}/lib/libnss_slurm.so.2 /usr/lib64/libnss_slurm.so.2".format(
            slurmdirs.prefix
        ),
        check=False,
    )
    run(r"sed -i 's/\(^\(passwd\|group\):\s\+\)/\1slurm /g' /etc/nsswitch.conf")


def configure_mysql():
    cnfdir = Path("/etc/my.cnf.d")
    if not cnfdir.exists():
        cnfdir = Path("/etc/mysql/conf.d")
    if not (cnfdir / "mysql_slurm.cnf").exists():
        (cnfdir / "mysql_slurm.cnf").write_text(
            """
[mysqld]
bind-address=127.0.0.1
innodb_buffer_pool_size=1024M
innodb_log_file_size=64M
innodb_lock_wait_timeout=900
"""
        )
    run("systemctl enable mariadb", timeout=30)
    run("systemctl restart mariadb", timeout=30)

    mysql = "mysql -u root -e"
    run(f"""{mysql} "drop user 'slurm'@'localhost'";""", timeout=30, check=False)
    run(f"""{mysql} "create user 'slurm'@'localhost'";""", timeout=30)
    run(
        f"""{mysql} "grant all on slurm_acct_db.* TO 'slurm'@'localhost'";""",
        timeout=30,
    )
    run(
        f"""{mysql} "drop user 'slurm'@'{lkp.control_host}'";""",
        timeout=30,
        check=False,
    )
    run(f"""{mysql} "create user 'slurm'@'{lkp.control_host}'";""", timeout=30)
    run(
        f"""{mysql} "grant all on slurm_acct_db.* TO 'slurm'@'{lkp.control_host}'";""",
        timeout=30,
    )


def configure_dirs():

    for p in dirs.values():
        p.mkdirp()
    util.chown_slurm(dirs.slurm)
    util.chown_slurm(dirs.scripts)

    for p in slurmdirs.values():
        p.mkdirp()
        util.chown_slurm(p)

    etc_slurm = Path("/etc/slurm")
    if etc_slurm.exists() and etc_slurm.is_symlink():
        etc_slurm.unlink()
    etc_slurm.symlink_to(slurmdirs.etc)

    scripts_etc = dirs.scripts / "etc"
    if scripts_etc.exists() and scripts_etc.is_symlink():
        scripts_etc.unlink()
    scripts_etc.symlink_to(slurmdirs.etc)

    scripts_log = dirs.scripts / "log"
    if scripts_log.exists() and scripts_log.is_symlink():
        scripts_log.unlink()
    scripts_log.symlink_to(dirs.log)


def setup_controller():
    """Run controller setup"""
    log.info("Setting up controller")
    util.chown_slurm(dirs.scripts / "config.yaml", mode=0o600)
    install_custom_scripts()

    install_slurm_conf(lkp)
    install_slurmdbd_conf(lkp)

    gen_cloud_conf()
    gen_cloud_gres_conf()
    install_gres_conf()
    install_cgroup_conf()

    setup_jwt_key()
    setup_munge_key()

    if cfg.controller_secondary_disk:
        setup_secondary_disks()
    setup_network_storage()

    run_custom_scripts()

    if not cfg.cloudsql:
        configure_mysql()

    run("systemctl enable slurmdbd", timeout=30)
    run("systemctl restart slurmdbd", timeout=30)

    # Wait for slurmdbd to come up
    time.sleep(5)

    sacctmgr = f"{slurmdirs.prefix}/bin/sacctmgr -i"
    result = run(
        f"{sacctmgr} add cluster {cfg.slurm_cluster_name}", timeout=30, check=False
    )
    if "already exists" in result.stdout:
        log.info(result.stdout)
    elif result.returncode > 1:
        result.check_returncode()  # will raise error

    run("systemctl enable slurmctld", timeout=30)
    run("systemctl restart slurmctld", timeout=30)

    run("systemctl enable slurmrestd", timeout=30)
    run("systemctl restart slurmrestd", timeout=30)

    # Export at the end to signal that everything is up
    run("systemctl enable nfs-server", timeout=30)
    run("systemctl start nfs-server", timeout=30)

    run("systemctl enable slurmeventd", timeout=30)
    run("systemctl restart slurmeventd", timeout=30)

    setup_nfs_exports()
    setup_sync_cronjob()

    log.info("Check status of cluster services")
    run("systemctl status munge", timeout=30)
    run("systemctl status slurmdbd", timeout=30)
    run("systemctl status slurmctld", timeout=30)
    run("systemctl status slurmrestd", timeout=30)
    run("systemctl status slurmeventd", timeout=30)

    slurmsync.sync_slurm()
    run("systemctl enable slurm_load_bq.timer", timeout=30)
    run("systemctl start slurm_load_bq.timer", timeout=30)
    run("systemctl status slurm_load_bq.timer", timeout=30)

    log.info("Done setting up controller")
    pass


def setup_login():
    """run login node setup"""
    log.info("Setting up login")
    install_custom_scripts()

    setup_network_storage()
    run("systemctl restart munge")

    run_custom_scripts()

    log.info("Check status of cluster services")
    run("systemctl status munge", timeout=30)

    log.info("Done setting up login")


def setup_compute():
    """run compute node setup"""
    log.info("Setting up compute")
    util.chown_slurm(dirs.scripts / "config.yaml", mode=0o600)
    install_custom_scripts()

    setup_nss_slurm()
    setup_network_storage()

    has_gpu = run("lspci | grep --ignore-case 'NVIDIA' | wc -l", shell=True).returncode
    if has_gpu:
        run("nvidia-smi")

    run_custom_scripts()

    setup_slurmd_cronjob()
    run("systemctl restart munge", timeout=30)
    run("systemctl enable slurmd", timeout=30)
    run("systemctl restart slurmd", timeout=30)

    run("systemctl enable slurmeventd", timeout=30)
    run("systemctl restart slurmeventd", timeout=30)

    log.info("Check status of cluster services")
    run("systemctl status munge", timeout=30)
    run("systemctl status slurmd", timeout=30)
    run("systemctl status slurmeventd", timeout=30)

    log.info("Done setting up compute")


def main():

    start_motd()
    configure_dirs()
    fetch_devel_scripts()

    # call the setup function for the instance type
    setup = dict.get(
        {
            "controller": setup_controller,
            "compute": setup_compute,
            "login": setup_login,
        },
        lkp.instance_role,
        lambda: log.fatal(f"Unknown node role: {lkp.instance_role}"),
    )
    setup()

    end_motd()


if __name__ == "__main__":
    util.chown_slurm(LOGFILE, mode=0o600)
    util.config_root_logger(filename, logfile=LOGFILE)
    sys.excepthook = util.handle_exception

    lkp = util.Lookup(cfg)  # noqa F811

    try:
        main()
    except subprocess.TimeoutExpired as e:
        log.error(
            f"""TimeoutExpired:
    command={e.cmd}
    timeout={e.timeout}
    stdout:
{e.stdout.strip()}
    stderr:
{e.stderr.strip()}
"""
        )
        log.error("Aborting setup...")
        failed_motd()
    except subprocess.CalledProcessError as e:
        log.error(
            f"""CalledProcessError:
    command={e.cmd}
    returncode={e.returncode}
    stdout:
{e.stdout.strip()}
    stderr:
{e.stderr.strip()}
"""
        )
        log.error("Aborting setup...")
        failed_motd()
    except Exception as e:
        log.exception(e)
        log.error("Aborting setup...")
        failed_motd()
