#!/usr/bin/env python3

# Copyright 2017 SchedMD LLC.
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

import logging
import os
import re
import shutil
import subprocess
import sys
import time
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, Future
from functools import reduce, partialmethod, lru_cache
from itertools import chain
from pathlib import Path
from subprocess import DEVNULL

import yaml
from addict import Dict as NSDict

import util
from util import run, instance_metadata

SETUP_SCRIPT = Path(__file__)
LOGFILE = SETUP_SCRIPT.with_suffix('.log')

Path.mkdirp = partialmethod(Path.mkdir, parents=True, exist_ok=True)

util.config_root_logger(logfile=LOGFILE)
log = logging.getLogger(SETUP_SCRIPT.name)
sys.excepthook = util.handle_exception

# load all directories as Paths into a dict-like namespace
dirs = NSDict({n: Path(p) for n, p in dict.items({
    'home': '/home',
    'apps': '/opt/apps',
    'scripts': '/slurm/scripts',
    'slurm': '/slurm',
    'prefix': '/usr/local',
    'munge': '/etc/munge',
    'secdisk': '/mnt/disks/sec',
})})

slurmdirs = NSDict({n: Path(p) for n, p in dict.items({
    'etc': '/usr/local/etc/slurm',
    'log': '/var/log/slurm',
    'state': '/var/spool/slurm',
})})

# get setup config from metadata
config_yaml = yaml.safe_load(instance_metadata('attributes/config'))
cfg = util.new_config(config_yaml)
lkp = util.Lookup(cfg)

RESUME_TIMEOUT = 300
SUSPEND_TIMEOUT = 300

CONTROL_MACHINE = cfg.cluster_name + '-controller'

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
    """ advise in motd that slurm is currently configuring """
    wall_msg = "*** Slurm is currently being configured in the background. ***"
    motd_msg = MOTD_HEADER + wall_msg + '\n\n'
    Path('/etc/motd').write_text(motd_msg)
    util.run(f"wall -n '{wall_msg}'", timeout=30)
# END start_motd()


def end_motd(broadcast=True):
    """ modify motd to signal that setup is complete """
    Path('/etc/motd').write_text(MOTD_HEADER)

    if not broadcast:
        return

    run("wall -n '*** Slurm {} setup complete ***'".format(lkp.node_role),
        timeout=30)
    if lkp.node_role != 'controller':
        run("""wall -n '
/home on the controller was mounted over the existing /home.
Log back in to ensure your home directory is correct.
'""", timeout=30)
# END start_motd()


def failed_motd():
    """ modify motd to signal that setup is failed """
    wall_msg = f"*** Slurm setup failed! Please view log: {LOGFILE} ***"
    motd_msg = MOTD_HEADER + wall_msg + '\n\n'
    Path('/etc/motd').write_text(motd_msg)
    util.run(f"wall -n '{wall_msg}'", timeout=30)


def nodeset(node):
    return f'{cfg.cluster_name}-{node.template}-{node.partition}'


def nodenames(node):
    """ Return static and dynamic nodenames given a partition node type
    definition
    """
    # ... hack... ensure template_nodes was generated so partition is in node
    # dict
    lkp.template_nodes

    def node_range(count, start=0):
        end = start + count - 1
        return f'{start}' if count == 1 else f'[{start}-{end}]', end + 1

    prefix = nodeset(node)
    static_range, end = (
        node_range(node.count_static) if node.count_static else (None, 0)
    )
    dynamic_range, _ = (
        node_range(node.count_dynamic, end) if node.count_dynamic else (None, 0)
    )

    static_name = f'{prefix}-{static_range}' if node.count_static else None
    dynamic_name = f'{prefix}-{dynamic_range}' if node.count_dynamic else None
    return static_name, dynamic_name


def dict_to_conf(conf):
    """ convert dict to space-delimited slurm-style key-value pairs """
    return ' '.join(f'{k}={v}' for k, v in conf.items() if v is not None)


def gen_cloud_nodes_conf():
    def nodeline(template):
        props = lkp.template_details(template)
        machine = props.machine

        node_def = dict_to_conf({
            'NodeName': 'DEFAULT',
            'State': 'UNKNOWN',
            'RealMemory': machine.memory,
            'Sockets': 1,
            'CoresPerSocket': machine.cpus,
            'ThreadsPerCore': 1,
        })

        gres = f'gpu:{machine.gpu_count}' if machine.gpu_count else None

        nodelines = []
        for node in lkp.template_nodes[template]:
            static, dynamic = nodenames(node)
            nodelines.append(dict_to_conf({
                'NodeName': static,
                'State': 'CLOUD',
                'Gres': gres,
            }) if static else None
            )
            nodelines.append(dict_to_conf({
                'NodeName': dynamic,
                'State': 'CLOUD',
                'Gres': gres,
            }) if dynamic else None
            )
            nodelines.append(dict_to_conf({
                'NodeSet': nodeset(node),
                'Nodes': ','.join(filter(None, (static, dynamic))),
            }))

        return '\n'.join(filter(None, chain([node_def], nodelines)))

    def partitionline(part_name):
        """ Make a partition line for the slurm.conf """
        partition = cfg.partitions[part_name]
        nodesets = ','.join(nodeset(node)for node in partition.nodes)

        def defmempercpu(machine):
            return max(100, machine.memory // machine.cpus)

        defmem = min(
            defmempercpu(lkp.template_details(node.template).machine)
            for node in partition.nodes
        )
        line_elements = {
            'PartitionName': part_name,
            'Nodes': nodesets,
            'State': 'UP',
            'DefMemPerCPU': defmem,
            'LLN': 'yes',
            'Oversubscribe': 'Exclusive' if partition.exclusive else None,
            **partition.conf,
        }

        return dict_to_conf(line_elements)

    static_nodes = ','.join(filter(None, (
        nodenames(node)[0]
        for part in cfg.partitions.values()
        for node in part.nodes
    )))
    suspend_exc = dict_to_conf({
        'SuspendExcNodes': static_nodes,
    }) if static_nodes else None

    preamble = """
# This file was generated by a script. It may be overwritten if the script is
# run again.
"""

    # lkp.template_nodes triggers the long api lookup calls
    lines = [
        preamble,
        *(nodeline(t) for t in lkp.template_nodes),
        *(partitionline(p) for p in cfg.partitions),
        suspend_exc,
    ]
    cloud_conf = slurmdirs.etc/'cloud.conf'

    content = '\n\n'.join(filter(None, lines))
    cloud_conf.write_text(content + '\n')


def install_slurm_conf():
    """ install slurm.conf """

    if cfg.ompi_version:
        mpi_default = "pmi2"
    else:
        mpi_default = "none"

    conf_options = {
        'name': cfg.cluster_name,
        'control_host': CONTROL_MACHINE,
        'scripts': dirs.scripts,
        'slurmlog': slurmdirs.log,
        'state_save': slurmdirs.state,
        'resume_timeout': RESUME_TIMEOUT,
        'suspend_timeout': SUSPEND_TIMEOUT,
        'suspend_time': cfg.suspend_time,
        'mpi_default': mpi_default,
    }
    conf_resp = instance_metadata('attributes/slurm_conf_tpl')
    conf = conf_resp.format(**conf_options)

    conf_file = slurmdirs.etc/'slurm.conf'
    conf_file.write_text(conf)
    shutil.chown(conf_file, user='slurm', group='slurm')
# END install_slurm_conf()


def install_slurmdbd_conf():
    """ install slurmdbd.conf """
    conf_options = NSDict({
        'control_host': CONTROL_MACHINE,
        'slurmlog': slurmdirs.log,
        'state_save': slurmdirs.state,
        'db_name': 'slurm_acct_db',
        'db_user': 'slurm',
        'db_pass': '""',
        'db_host': 'localhost',
        'db_port': '3306'
    })
    if cfg.cloudsql:
        conf_options.db_name = cfg.cloudsql.db_name
        conf_options.db_user = cfg.cloudsql.user
        conf_options.db_pass = cfg.cloudsql.password

        db_host_str = cfg.cloudsql.server_ip.split(':')
        conf_options.db_host = db_host_str[0]
        conf_options.db_port = (
            db_host_str[1] if len(db_host_str) >= 2 else '3306'
        )

    conf_resp = instance_metadata('attributes/slurmdbd_conf_tpl')
    conf = conf_resp.format(**conf_options)

    conf_file = slurmdirs.etc/'slurmdbd.conf'
    conf_file.write_text(conf)
    shutil.chown(conf_file, user='slurm', group='slurm')
    conf_file.chmod(0o600)
# END install_slurmdbd_conf()


def install_cgroup_conf():
    """ install cgroup.conf """
    conf = instance_metadata('attributes/cgroup_conf_tpl')

    conf_file = slurmdirs.etc/'cgroup.conf'
    conf_file.write_text(conf)
    shutil.chown(conf_file, user='slurm', group='slurm')


def install_gres_conf():
    """ install gres.conf """

    gpu_nodes = defaultdict(list)
    for part in cfg.partitions.values():
        for node in part.nodes:
            gpu_count = node.template_details.machine.gpu_count
            if gpu_count == 0:
                continue
            gpu_nodes[gpu_count].extend(
                filter(None, nodenames(node))
            )

    lines = [
        dict_to_conf({
            'NodeName': names,
            'Name': 'gpu',
            'File': '/dev/nvidia{}'.format(f'[0-{i-1}]' if i > 1 else '0'),
        }) for i, names in gpu_nodes.items()
    ]
    if lines:
        content = '\n'.join(lines)
        (slurmdirs.etc/'gres.conf').write_text(content)


def fetch_devel_scripts():
    """download scripts from project metadata if they are present"""

    metadata = lkp.project_metadata

    meta_entries = [
        ('suspend.py', 'slurm-suspend'),
        ('resume.py', 'slurm-resume'),
        ('slurmsync.py', 'slurmsync'),
        ('util.py', 'util-script'),
        ('setup.py', 'setup-script'),
        ('startup.sh', 'startup-script'),
    ]

    for script, name in meta_entries:
        if name not in metadata:
            continue
        content = metadata[name]
        path = (dirs.scripts/script).resolve()
        # make sure parent dir exists
        path.write_text(content)
        path.chmod(0o755)
        shutil.chown(path, user='slurm', group='slurm')


def install_custom_compute_scripts():
    """"""
    custom_pattern = re.compile(r'custom-compute-(S+)')
    metadata = lkp.project_metadata
    custom_scripts = [
        (f'custom-compute.d/{m[1]}', content)
        for name, content in metadata.items()
        if (m := custom_pattern.match(name))
    ]
    for name, content in custom_scripts:
        path = (dirs.scripts/name).resolve()
        path.write_text(content)
        path.chmod(0o755)
        shutil.chown(path, user='slurm', group='slurm')


def local_mounts(mountlist):
    """convert network_storage list of mounts to dict of mounts,
    local_mount as key
    """
    return {str(Path(m.local_mount).resolve()): m for m in mountlist}


@lru_cache(maxsize=None)
def resolve_network_storage(partition_name=None):
    """Combine appropriate network_storage fields to a single list
    """

    partition = cfg.partitions[partition_name] if partition_name else None

    default_mounts = (
        slurmdirs.etc,
        dirs.munge,
        dirs.home,
        dirs.apps,
    )

    # create dict of mounts, local_mount: mount_info
    CONTROL_NFS = {
        'server_ip': CONTROL_MACHINE,
        'remote_mount': 'none',
        'local_mount': 'none',
        'fs_type': 'nfs',
        'mount_options': 'defaults,hard,intr',
    }

    # seed mounts with the default controller mounts
    mounts = local_mounts([
        NSDict(CONTROL_NFS, local_mount=str(path), remote_mount=str(path))
        for path in default_mounts
    ])
    # On non-controller instances, entries in network_storage could overwrite
    # default exports from the controller. Be careful, of course
    mounts.update(local_mounts(cfg.network_storage))
    mounts.update(local_mounts(cfg.login_network_storage))

    # this part is not actually run from compute nodes. A pre-resolved
    # network_storage will be passed to them.
    if partition is not None:
        mounts.update(local_mounts(partition.network_storage))
    return list(mounts.values())


def partition_mounts(mounts):
    """partition into cluster-external and internal mounts
    """
    def internal_mount(mount):
        return mount.server_ip == CONTROL_MACHINE

    def partition(pred, coll):
        """ filter into 2 lists based on pred returning True or False
            returns ([False], [True])
        """
        return reduce(lambda acc, el: acc[pred(el)].append(el) or acc,
                      coll, ([], []))
    return partition(internal_mount, mounts)


def setup_network_storage():
    """ prepare network fs mounts and add them to fstab """
    log.info("Set up network storage")
    # filter mounts into two dicts, cluster-internal and external mounts

    all_mounts = resolve_network_storage()
    ext_mounts, int_mounts = partition_mounts(all_mounts)
    mounts = ext_mounts
    if lkp.node_role != 'controller':
        mounts.extend(int_mounts)

    # Determine fstab entries and write them out
    fstab_entries = []
    for mount in mounts:
        local_mount = Path(mount.local_mount)
        remote_mount = mount.remote_mount
        fs_type = mount.fs_type
        server_ip = mount.server_ip
        local_mount.mkdirp()

        log.info("Setting up mount ({}) {}{} to {}".format(
            fs_type, server_ip+':' if fs_type != 'gcsfuse' else "",
            remote_mount, local_mount))

        mount_options = (mount.mount_options.split(',') if mount.mount_options
                         else [])
        if not mount_options or '_netdev' not in mount_options:
            mount_options += ['_netdev']

        if fs_type == 'gcsfuse':
            if 'nonempty' not in mount_options:
                mount_options += ['nonempty']
            fstab_entries.append(
                "{0}   {1}     {2}     {3}     0 0"
                .format(remote_mount, local_mount, fs_type,
                        ','.join(mount_options)))
        else:
            fstab_entries.append(
                "{0}:{1}    {2}     {3}      {4}  0 0"
                .format(server_ip, remote_mount, local_mount,
                        fs_type, ','.join(mount_options)))

    with open('/etc/fstab', 'a') as f:
        f.write('\n')
        for entry in fstab_entries:
            f.write(entry)
            f.write('\n')

    mount_fstab(local_mounts(mounts))
# END setup_network_storage()


def mount_fstab(mounts):
    """ Wait on each mount, then make sure all fstab is mounted """

    def mount_path(path):
        log.info(f"Waiting for '{path}' to be mounted...")
        run(f"mount {path}", timeout=60)
        log.info(f"Mount point '{path}' was mounted.")

    future_list = []
    with ThreadPoolExecutor() as exe:
        for path in mounts:
            future = exe.submit(mount_path, path)
            future_list.append(future)

        # Iterate over futures, checking for exceptions
        for future in future_list:
            result = future.exception(timeout=60)
            if result is not None:
                raise result
# END mount_external


def setup_nfs_exports():
    """ nfs export all needed directories """
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

    exportsd = Path('/etc/exports.d')
    exportsd.mkdirp()
    with (exportsd/'slurm.exports').open('w') as f:
        f.write('\n')
        f.write('\n'.join(exports))
    run("exportfs -a", timeout=30)
# END setup_nfs_exports()


def setup_secondary_disks():
    """ Format and mount secondary disk """
    run("sudo mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb")
    with open('/etc/fstab', 'a') as f:
        f.write(
            "\n/dev/sdb     {0}     ext4    discard,defaults,nofail     0 2"
            .format(dirs.secdisk))

# END setup_secondary_disks()


def setup_sync_cronjob():
    """ Create cronjob for running slurmsync.py """
    run("crontab -u slurm -", input=(f"*/1 * * * * {dirs.scripts}/slurmsync.py\n"))

# END setup_sync_cronjob()


def setup_jwt_key():
    jwt_key = slurmdirs.state/'jwt_hs256.key'

    if cfg.jwt_key:
        with (jwt_key).open('w') as f:
            f.write(cfg.jwt_key)
    else:
        run("dd if=/dev/urandom bs=32 count=1 >"+str(jwt_key), shell=True)

    run(f"chown -R slurm:slurm {jwt_key}")
    jwt_key.chmod(0o400)


def setup_slurmd_cronjob():
    """ Create cronjob for keeping slurmd service up """
    run("crontab -u root -", input=(
        "*/2 * * * * "
        "if [ `systemctl status slurmd | grep -c inactive` -gt 0 ]; then "
        "mount -a; "
        "systemctl restart munge; "
        "systemctl restart slurmd; "
        "fi\n"
    ), timeout=30)
# END setup_slurmd_cronjob()


def setup_nss_slurm():
    """ install and configure nss_slurm """
    # setup nss_slurm
    Path('/var/spool/slurmd').mkdirp()
    run("ln -s {}/lib/libnss_slurm.so.2 /usr/lib64/libnss_slurm.so.2"
        .format(dirs.prefix), check=False)
    run(
        r"sed -i 's/\(^\(passwd\|group\):\s\+\)/\1slurm /g' /etc/nsswitch.conf")
# END setup_nss_slurm()


def configure_mysql():
    cnfdir = Path('/etc/my.cnf.d')
    if not cnfdir.exists():
        cnfdir = Path('/etc/mysql/conf.d')
    if not (cnfdir/'mysql_slurm.cnf').exists():
        (cnfdir/'mysql_slurm.cnf').write_text("""
[mysqld]
bind-address=127.0.0.1
innodb_buffer_pool_size=1024M
innodb_log_file_size=64M
innodb_lock_wait_timeout=900
""")
    run('systemctl enable mariadb', timeout=30)
    run('systemctl restart mariadb', timeout=30)

    mysql = "mysql -u root -e"
    run(f"""{mysql} "grant all on slurm_acct_db.* TO 'slurm'@'localhost'";""",
        timeout=30)
    run(f"""{mysql} "grant all on slurm_acct_db.* TO 'slurm'@'{CONTROL_MACHINE}'";""",
        timeout=30)


def configure_dirs():

    for p in dirs.values():
        p.mkdir(parents=True, exist_ok=True)
    shutil.chown(dirs.slurm, user='slurm', group='slurm')
    shutil.chown(dirs.scripts, user='slurm', group='slurm')

    for p in slurmdirs.values():
        p.mkdir(parents=True, exist_ok=True)
        shutil.chown(p, user='slurm', group='slurm')

    scripts_etc = dirs.scripts/'etc'
    if scripts_etc.exists() and scripts_etc.is_symlink():
        scripts_etc.unlink()
    scripts_etc.symlink_to(slurmdirs.etc)
    shutil.chown(scripts_etc, user='slurm', group='slurm')

    scripts_log = dirs.scripts/'log'
    if scripts_log.exists() and scripts_log.is_symlink():
        scripts_log.unlink()
    scripts_log.symlink_to(slurmdirs.log)
    shutil.chown(scripts_log, user='slurm', group='slurm')


def run_custom_scripts():
    """ run custom scripts based on node role """
    custom_dir = dirs.scripts/'custom'
    if lkp.node_role == 'controller':
        custom_dir = custom_dir/'controller.d'
    custom_scripts = (
        p for p in custom_dir.rglob('*') if not p.name.endswith('.disabled')
    )

    try:
        for script in custom_scripts:
            result = run(str(script), timeout=300)
        log.info(f"""
returncode={result.returncode}
stdout={result.stdout}
stdout={result.stderr}
"""[1:])
    except Exception:
        # Ignore blank files with no shell magic.
        pass


def setup_controller():
    """ Run controller setup """
    log.info("Setting up controller")
    util.save_config(cfg, dirs.scripts/'config.yaml')
    shutil.chown(dirs.scripts/'config.yaml', user='slurm', group='slurm')

    install_slurm_conf()
    install_slurmdbd_conf()

    gen_cloud_nodes_conf()
    install_cgroup_conf()
    install_gres_conf()

    setup_jwt_key()
    run("create-munge-key -f", timeout=30)
    run("systemctl restart munge", timeout=30)

    if cfg.controller_secondary_disk:
        setup_secondary_disks()
    setup_network_storage()

    run_custom_scripts()

    if not cfg.cloudsql:
        configure_mysql()

    run("systemctl enable slurmdbd", timeout=30)
    run("systemctl start slurmdbd", timeout=30)

    # Wait for slurmdbd to come up
    time.sleep(5)

    sacctmgr = f"{dirs.prefix}/bin/sacctmgr -i"
    result = run(f"{sacctmgr} add cluster {cfg.cluster_name}",
                 timeout=30, check=False)
    if "This cluster slurm already exists." in result.stdout:
        log.info(result.stdout)
    elif result.returncode > 1:
        result.check_returncode()  # will raise error

    run("systemctl enable slurmctld", timeout=30)
    run("systemctl start slurmctld", timeout=30)

    run("systemctl enable slurmrestd", timeout=30)
    run("systemctl start slurmrestd", timeout=30)

    # Export at the end to signal that everything is up
    run("systemctl enable nfs-server", timeout=30)
    run("systemctl start nfs-server", timeout=30)

    setup_nfs_exports()
    setup_sync_cronjob()

    log.info("Done setting up controller")
    pass


def setup_login():
    """ run login node setup """
    log.info("Setting up login")

    setup_network_storage()
    run("systemctl restart munge")

    run_custom_scripts()

    log.info("Done setting up login")


def setup_compute():
    """ run compute node setup """
    log.info("Setting up compute")
    setup_nss_slurm()
    setup_network_storage()

    template = lkp.node_template_details(lkp.hostname)
    # if (not cfg.instance_defs[pid].image_hyperthreads and
    #         shutil.which('google_mpi_tuning')):
    #     run("google_mpi_tuning --nosmt")

    if template.machine.gpu_count:
        retries = n = 50
        while n:
            if run("nvidia-smi").returncode == 0:
                break
            n -= 1
            log.info(f"Nvidia driver not yet loaded, try {retries-n}")
            time.sleep(5)
        else:
            # nvidia driver failed to load
            return

    run_custom_scripts()

    setup_slurmd_cronjob()
    run("systemctl restart munge", timeout=30)
    run("systemctl enable slurmd", timeout=30)
    run("systemctl start slurmd", timeout=30)

    log.info("Done setting up compute")


def main():

    start_motd()
    configure_dirs()
    fetch_devel_scripts()

    # call the setup function for the instance type
    setup = dict.get(
        {
            'controller': setup_controller,
            'compute': setup_compute,
            'login': setup_login
        },
        lkp.node_role,
        lambda: log.fatal(f"Unknown node role: {lkp.node_role}")
    )
    setup()

    end_motd()
# END main()


if __name__ == '__main__':
    try:
        main()
    except subprocess.TimeoutExpired as e:
        log.error(f"""TimeoutExpired:
    command={e.cmd}
    timeout={e.timeout}
    stdout:
{e.stdout.strip()}
    stderr:
{e.stderr.strip()}
""")
        log.error("Aborting setup...")
        failed_motd()
    except subprocess.CalledProcessError as e:
        log.error(f"""CalledProcessError:
    command={e.cmd}
    returncode={e.returncode}
    stdout:
{e.stdout.strip()}
    stderr:
{e.stderr.strip()}
""")
        log.error("Aborting setup...")
        failed_motd()
    except Exception as e:
        log.exception(e)
        log.error("Aborting setup...")
        failed_motd()
