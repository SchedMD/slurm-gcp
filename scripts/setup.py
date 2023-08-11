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

import argparse
import logging
import os
import re
import shutil
import subprocess
import sys
import stat
import time
import socket
from concurrent.futures import as_completed
from functools import partialmethod, lru_cache
from itertools import chain
from pathlib import Path

from addict import Dict as NSDict

import util
from util import (
    run,
    separate,
    blob_list,
)
from util import lkp, cfg, dirs, slurmdirs
from conf import (
    install_slurm_conf,
    install_slurmdbd_conf,
    gen_cloud_conf,
    gen_cloud_gres_conf,
    gen_topology_conf,
    install_gres_conf,
    install_cgroup_conf,
    install_topology_conf,
    install_jobsubmit_lua,
    login_nodeset,
)
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


def install_custom_scripts(clean=False):
    """download custom scripts from gcs bucket"""

    compute_tokens = ["compute", "prolog", "epilog"]
    if lkp.instance_role == "compute":
        try:
            compute_tokens.append(f"partition-{lkp.node_partition_name()}")
        except Exception as e:
            log.error(f"Failed to lookup node partition: {e}")

    prefix_tokens = dict.get(
        {
            "login": ["login"],
            "compute": compute_tokens,
            "controller": ["controller", "prolog", "epilog"],
        },
        lkp.instance_role,
        [],
    )
    prefixes = [f"slurm-{tok}-script" for tok in prefix_tokens]
    blobs = list(chain.from_iterable(blob_list(prefix=p) for p in prefixes))

    if clean:
        path = Path(dirs.custom_scripts)
        if path.exists() and path.is_dir():
            # rm -rf custom_scripts
            shutil.rmtree(path)

    script_pattern = re.compile(r"slurm-(?P<path>\S+)-script-(?P<name>\S+)")
    for blob in blobs:
        m = script_pattern.match(Path(blob.name).name)
        if not m:
            log.warning(f"found blob that doesn't match expected pattern: {blob.name}")
            continue
        path_parts = m["path"].split("-")
        path_parts[0] += ".d"
        stem, _, ext = m["name"].rpartition("_")
        filename = ".".join((stem, ext))

        path = Path(*path_parts, filename)
        fullpath = (dirs.custom_scripts / path).resolve()
        log.info(f"installing custom script: {path} from {blob.name}")
        fullpath.parent.mkdirp()
        for par in path.parents:
            util.chown_slurm(dirs.custom_scripts / par)
        with fullpath.open("wb") as f:
            blob.download_to_file(f)
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
        # login setup with only login.d
        custom_dirs = [custom_dir / "login.d"]
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
            if "/controller.d/" in str(script):
                timeout = lkp.cfg.get("controller_startup_scripts_timeout", 300)
            elif "/compute.d/" in str(script):
                timeout = lkp.cfg.get("compute_startup_scripts_timeout", 300)
            elif "/login.d/" in str(script):
                timeout = lkp.cfg.get("login_startup_scripts_timeout", 300)
            else:
                timeout = 300
            timeout = None if not timeout or timeout < 0 else timeout
            log.info(f"running script {script.name} with timeout={timeout}")
            result = run(str(script), timeout=timeout, check=False, shell=True)
            runlog = (
                f"{script.name} returncode={result.returncode}\n"
                f"stdout={result.stdout}stderr={result.stderr}"
            )
            log.info(runlog)
            result.check_returncode()
    except OSError as e:
        log.error(f"script {script} is not executable")
        raise e
    except subprocess.TimeoutExpired as e:
        log.error(f"script {script} did not complete within timeout={timeout}")
        raise e
    except Exception as e:
        log.error(f"script {script} encountered an exception")
        log.exception(e)
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
        try:
            partition_name = lkp.node_partition_name()
        except Exception:
            # External nodename, skip partition lookup
            partition_name = None
    partition = cfg.partitions[partition_name] if partition_name else None

    default_mounts = (
        dirs.home,
        dirs.apps,
    )

    # create dict of mounts, local_mount: mount_info
    CONTROL_NFS = {
        "server_ip": lkp.control_addr or lkp.control_host,
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
    if partition is None:
        mounts.update(local_mounts(cfg.login_network_storage))

    if partition is not None:
        mounts.update(local_mounts(partition.network_storage))
    return list(mounts.values())


def partition_mounts(mounts):
    """partition into cluster-external and internal mounts"""

    def internal_mount(mount):
        # NOTE: Valid Lustre server_ip can take the form of '<IP>@tcp'
        server_ip = mount.server_ip.split("@")[0]
        mount_addr = socket.gethostbyname(server_ip)
        return mount_addr == lkp.control_host_addr

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
        server_ip = mount.server_ip or ""
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
    munge_mount_handler()


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


def munge_mount_handler():
    if not cfg.munge_mount:
        log.error("Missing munge_mount in cfg")
    elif lkp.control_host == lkp.hostname:
        return

    mount = cfg.munge_mount
    server_ip = (
        mount.server_ip
        if mount.server_ip
        else (cfg.slurm_control_addr or cfg.slurm_control_host)
    )
    remote_mount = mount.remote_mount
    local_mount = Path("/mnt/munge")
    fs_type = mount.fs_type if mount.fs_type is not None else "nfs"
    mount_options = (
        mount.mount_options
        if mount.mount_options is not None
        else "defaults,hard,intr,_netdev"
    )

    munge_key = Path(dirs.munge / "munge.key")

    log.info(f"Mounting munge share to: {local_mount}")
    local_mount.mkdir()
    if fs_type.lower() == "gcsfuse".lower():
        if remote_mount is None:
            remote_mount = ""
        cmd = [
            "gcsfuse",
            f"--only-dir={remote_mount}" if remote_mount != "" else None,
            server_ip,
            str(local_mount),
        ]
    else:
        if remote_mount is None:
            remote_mount = Path("/etc/munge")
        cmd = [
            "mount",
            f"--types={fs_type}",
            f"--options={mount_options}" if mount_options != "" else None,
            f"{server_ip}:{remote_mount}",
            str(local_mount),
        ]
    # wait max 120s for munge mount
    timeout = 120
    for retry, wait in enumerate(util.backoff_delay(0.5, timeout), 1):
        try:
            run(cmd, timeout=timeout)
            break
        except Exception as e:
            log.error(
                f"munge mount failed: '{cmd}' {e}, try {retry}, waiting {wait:0.2f}s"
            )
            time.sleep(wait)
            err = e
            continue
    else:
        raise err

    log.info(f"Copy munge.key from: {local_mount}")
    shutil.copy2(Path(local_mount / "munge.key"), munge_key)

    log.info("Restrict permissions of munge.key")
    shutil.chown(munge_key, user="munge", group="munge")
    os.chmod(munge_key, stat.S_IRUSR)

    log.info(f"Unmount {local_mount}")
    if fs_type.lower() == "gcsfuse".lower():
        run(f"fusermount -u {local_mount}", timeout=120)
    else:
        run(f"umount {local_mount}", timeout=120)
    shutil.rmtree(local_mount)


def setup_nfs_exports():
    """nfs export all needed directories"""
    # The controller only needs to set up exports for cluster-internal mounts
    # switch the key to remote mount path since that is what needs exporting
    mounts = resolve_network_storage()
    # manually add munge_mount
    mounts.append(
        NSDict(
            {
                "server_ip": cfg.munge_mount.server_ip,
                "remote_mount": cfg.munge_mount.remote_mount,
                "local_mount": Path(f"{dirs.munge}_tmp"),
                "fs_type": cfg.munge_mount.fs_type,
                "mount_options": cfg.munge_mount.mount_options,
            }
        )
    )
    # controller mounts
    _, con_mounts = partition_mounts(mounts)
    con_mounts = {m.remote_mount: m for m in con_mounts}
    for part in cfg.partitions:
        # get internal mounts for each partition by calling
        # prepare_network_mounts as from a node in each partition
        part_mounts = resolve_network_storage(part)
        _, p_mounts = partition_mounts(part_mounts)
        part_mounts = {m.remote_mount: m for m in p_mounts}
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


def setup_sudoers():
    content = """
# Allow SlurmUser to manage the slurm daemons
slurm ALL= NOPASSWD: /usr/bin/systemctl restart slurmd.service
slurm ALL= NOPASSWD: /usr/bin/systemctl restart slurmctld.service
"""
    sudoers_file = Path("/etc/sudoers.d/slurm")
    sudoers_file.write_text(content)
    sudoers_file.chmod(0o0440)


def update_system_config(file, content):
    """Add system defaults options for service files"""
    sysconfig = Path("/etc/sysconfig")
    default = Path("/etc/default")

    if sysconfig.exists():
        conf_dir = sysconfig
    elif default.exists():
        conf_dir = default
    else:
        raise Exception("Cannot determine system configuration directory.")

    slurmd_file = Path(conf_dir, file)
    slurmd_file.write_text(content)


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


def setup_controller(args):
    """Run controller setup"""
    log.info("Setting up controller")
    util.chown_slurm(dirs.scripts / "config.yaml", mode=0o600)
    install_custom_scripts()

    install_slurm_conf(lkp)
    install_slurmdbd_conf(lkp)

    gen_cloud_conf()
    gen_cloud_gres_conf()
    gen_topology_conf()
    install_gres_conf()
    install_cgroup_conf()
    install_topology_conf()
    install_jobsubmit_lua()

    setup_jwt_key()
    setup_munge_key()
    setup_sudoers()

    if cfg.controller_secondary_disk:
        setup_secondary_disks()
    setup_network_storage()

    run_custom_scripts()

    if not cfg.cloudsql_secret:
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

    setup_nfs_exports()
    run("systemctl enable --now slurmcmd.timer", timeout=30)

    log.info("Check status of cluster services")
    run("systemctl status munge", timeout=30)
    run("systemctl status slurmdbd", timeout=30)
    run("systemctl status slurmctld", timeout=30)
    run("systemctl status slurmrestd", timeout=30)

    slurmsync.sync_slurm()
    run("systemctl enable slurm_load_bq.timer", timeout=30)
    run("systemctl start slurm_load_bq.timer", timeout=30)
    run("systemctl status slurm_load_bq.timer", timeout=30)

    log.info("Done setting up controller")
    pass


def setup_login(args):
    """run login node setup"""
    log.info("Setting up login")
    slurmctld_host = f"{lkp.control_host}"
    if lkp.control_addr:
        slurmctld_host = f"{lkp.control_host}({lkp.control_addr})"
    slurmd_options = [
        f"-N {lkp.hostname}",
        f'--conf-server="{slurmctld_host}:{lkp.control_host_port}"',
        f'--conf="Feature={login_nodeset}"',
        "-Z",
    ]
    sysconf = f"""SLURMD_OPTIONS='{" ".join(slurmd_options)}'"""
    update_system_config("slurmd", sysconf)
    install_custom_scripts()

    setup_network_storage()
    setup_slurmd_cronjob()
    setup_sudoers()
    run("systemctl restart munge")
    run("systemctl enable slurmd", timeout=30)
    run("systemctl restart slurmd", timeout=30)
    run("systemctl enable --now slurmcmd.timer", timeout=30)

    run_custom_scripts()

    log.info("Check status of cluster services")
    run("systemctl status munge", timeout=30)
    run("systemctl status slurmd", timeout=30)

    log.info("Done setting up login")


def setup_compute(args):
    """run compute node setup"""
    log.info("Setting up compute")
    util.chown_slurm(dirs.scripts / "config.yaml", mode=0o600)
    slurmctld_host = f"{lkp.control_host}"
    if lkp.control_addr:
        slurmctld_host = f"{lkp.control_host}({lkp.control_addr})"
    slurmd_options = [
        f"-N {lkp.hostname}",
        f'--conf-server="{slurmctld_host}:{lkp.control_host_port}"',
    ]
    if args.slurmd_feature is not None:
        slurmd_options.append(f'--conf="Feature={args.slurmd_feature}"')
        slurmd_options.append("-Z")
    sysconf = f"""SLURMD_OPTIONS='{" ".join(slurmd_options)}'"""
    update_system_config("slurmd", sysconf)
    install_custom_scripts()

    setup_nss_slurm()
    setup_network_storage()

    has_gpu = run("lspci | grep --ignore-case 'NVIDIA' | wc -l", shell=True).returncode
    if has_gpu:
        run("nvidia-smi")

    run_custom_scripts()

    setup_slurmd_cronjob()
    setup_sudoers()
    run("systemctl restart munge", timeout=30)
    run("systemctl enable slurmd", timeout=30)
    run("systemctl restart slurmd", timeout=30)
    run("systemctl enable --now slurmcmd.timer", timeout=30)

    log.info("Check status of cluster services")
    run("systemctl status munge", timeout=30)
    run("systemctl status slurmd", timeout=30)

    log.info("Done setting up compute")


def main(args):
    start_motd()
    configure_dirs()

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
    setup(args)

    end_motd()


if __name__ == "__main__":
    util.chown_slurm(LOGFILE, mode=0o600)

    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--slurmd-feature",
        dest="slurmd_feature",
        help="Feature for slurmd to register with. Controller ignores this option.",
    )
    args = parser.parse_args()

    util.config_root_logger(filename, logfile=LOGFILE)
    sys.excepthook = util.handle_exception

    lkp = util.Lookup(cfg)  # noqa F811

    try:
        main(args)
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
