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

import importlib
import logging
import os
import sys
import shutil
import time
from pathlib import Path
from subprocess import DEVNULL
from functools import reduce, partialmethod
from concurrent.futures import ThreadPoolExecutor

import googleapiclient.discovery
import requests
import yaml


# get util.py from metadata
UTIL_FILE = Path('/tmp/util.py')
try:
    resp = requests.get('http://metadata.google.internal/computeMetadata/v1/instance/attributes/util-script',
                        headers={'Metadata-Flavor': 'Google'})
    resp.raise_for_status()
    UTIL_FILE.write_text(resp.text)
except requests.exceptions.RequestException:
    print("util.py script not found in metadata")
    if not UTIL_FILE.exists():
        print(f"{UTIL_FILE} also does not exist, aborting")
        sys.exit(1)

spec = importlib.util.spec_from_file_location('util', UTIL_FILE)
util = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = util
spec.loader.exec_module(util)
cd = util.cd  # import util.cd into local namespace
NSDict = util.NSDict

Path.mkdirp = partialmethod(Path.mkdir, parents=True, exist_ok=True)

util.config_root_logger(logfile='/tmp/setup.log')
log = logging.getLogger(Path(__file__).name)
sys.excepthook = util.handle_exception

# get setup config from metadata
config_yaml = yaml.safe_load(util.get_metadata('attributes/config'))
cfg = util.Config.new_config(config_yaml)

# load all directories as Paths into a dict-like namespace
dirs = NSDict({n: Path(p) for n, p in dict.items({
    'home': '/home',
    'apps': '/apps',
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

cfg['log_dir'] = slurmdirs.log
cfg['slurm_cmd_path'] = dirs.prefix/'bin'

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
    msg = MOTD_HEADER + """
*** Slurm is currently being configured in the background. ***
"""
    Path('/etc/motd').write_text(msg)
# END start_motd()


def end_motd(broadcast=True):
    """ modify motd to signal that setup is complete """
    Path('/etc/motd').write_text(MOTD_HEADER)

    if not broadcast:
        return

    util.run("wall -n '*** Slurm {} setup complete ***'"
             .format(cfg.instance_type))
    if cfg.instance_type != 'controller':
        util.run("""wall -n '
/home on the controller was mounted over the existing /home.
Log back in to ensure your home directory is correct.
'""")
# END start_motd()


def expand_instance_templates():
    """ Expand instance template into instance_defs """

    compute = googleapiclient.discovery.build('compute', 'v1',
                                              cache_discovery=False)
    for pid, instance_def in cfg.instance_defs.items():
        if (instance_def.instance_template and
                (not instance_def.machine_type or not instance_def.gpu_count)):
            template_resp = util.ensure_execute(
                compute.instanceTemplates().get(
                    project=cfg.project,
                    instanceTemplate=instance_def.instance_template))
            if template_resp:
                template_props = template_resp['properties']
                if not instance_def.machine_type:
                    instance_def.machine_type = template_props['machineType']
                if (not instance_def.gpu_count and
                        'guestAccelerators' in template_props):
                    accel_props = template_props['guestAccelerators'][0]
                    instance_def.gpu_count = accel_props['acceleratorCount']
                    instance_def.gpu_type = accel_props['acceleratorType']
# END expand_instance_templates()


def expand_machine_type():
    """ get machine type specs from api """
    machines = {}
    compute = googleapiclient.discovery.build('compute', 'v1',
                                              cache_discovery=False)
    for pid, part in cfg.instance_defs.items():
        machine = {'cpus': 1, 'memory': 1}
        machines[pid] = machine

        if not part.machine_type:
            log.error("No machine type to get configuration from")
            continue

        type_resp = None
        if part.regional_capacity:
            filter = f"(zone={part.region}-*) AND (name={part.machine_type})"
            list_resp = util.ensure_execute(
                compute.machineTypes().aggregatedList(
                    project=cfg.project, filter=filter))

            if 'items' in list_resp:
                zone_types = list_resp['items']
                for k, v in zone_types.items():
                    if part.region in k and 'machineTypes' in v:
                        type_resp = v['machineTypes'][0]
                        break
        else:
            type_resp = util.ensure_execute(
                compute.machineTypes().get(
                    project=cfg.project, zone=part.zone,
                    machineType=part.machine_type))

        if type_resp:
            cpus = type_resp['guestCpus']
            machine['cpus'] = (
                cpus // (1 if part.image_hyperthreads else 2) or 1
            )

            # Because the actual memory on the host will be different than
            # what is configured (e.g. kernel will take it). From
            # experiments, about 16 MB per GB are used (plus about 400 MB
            # buffer for the first couple of GB's. Using 30 MB to be safe.
            gb = type_resp['memoryMb'] // 1024
            machine['memory'] = type_resp['memoryMb'] - (400 + (gb * 30))

    return machines
# END expand_machine_type()


def install_slurm_conf():
    """ install slurm.conf """
    machines = expand_machine_type()

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
    conf_resp = util.get_metadata('attributes/slurm_conf_tpl')
    conf = conf_resp.format(**conf_options)

    static_nodes = []
    for i, (pid, machine) in enumerate(machines.items()):
        part = cfg.instance_defs[pid]
        static_range = ''
        if part.static_node_count:
            if part.static_node_count > 1:
                static_range = '{}-[0-{}]'.format(
                    pid, part.static_node_count - 1)
            else:
                static_range = f"{pid}-0"

        cloud_range = ""
        if (part.max_node_count and
                (part.max_node_count != part.static_node_count)):
            cloud_range = "{}-[{}-{}]".format(
                pid, part.static_node_count,
                part.max_node_count - 1)

        conf += ("NodeName=DEFAULT "
                 "Sockets=1 "
                 f"CoresPerSocket={machine['cpus']} "
                 "ThreadsPerCore=1 "
                 f"RealMemory={machine['memory']} "
                 "State=UNKNOWN")
        conf += '\n'

        # Nodes
        gres = ""
        if part.gpu_count:
            gres = " Gres=gpu:" + str(part.gpu_count)
        if static_range:
            static_nodes.append(static_range)
            conf += f"NodeName={static_range}{gres}\n"

        if cloud_range:
            conf += f"NodeName={cloud_range} State=CLOUD{gres}\n"

        # instance_defs
        part_nodes = f'{pid}-[0-{part.max_node_count - 1}]'

        def_mem_per_cpu = max(100, machine['memory'] // machine['cpus'])

        conf += ("PartitionName={} Nodes={} MaxTime=INFINITE "
                 "State=UP DefMemPerCPU={} LLN=yes"
                 .format(part.name, part_nodes,
                         def_mem_per_cpu))
        if part.exclusive:
            conf += " Oversubscribe=Exclusive"

        # First partition specified is treated as the default partition
        if i == 0:
            conf += " Default=YES"
        conf += "\n\n"

    if len(static_nodes):
        conf += "\nSuspendExcNodes={}\n".format(','.join(static_nodes))

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
        conf_options.db_port = db_host_str[1] if len(db_host_str) >= 2 else '3306'

    conf_resp = util.get_metadata('attributes/slurmdbd_conf_tpl')
    conf = conf_resp.format(**conf_options)

    conf_file = slurmdirs.etc/'slurmdbd.conf'
    conf_file.write_text(conf)
    shutil.chown(conf_file, user='slurm', group='slurm')
    conf_file.chmod(0o600)
# END install_slurmdbd_conf()


def install_cgroup_conf():
    """ install cgroup.conf """
    conf = util.get_metadata('attributes/cgroup_conf_tpl')

    conf_file = slurmdirs.etc/'cgroup.conf'
    conf_file.write_text(conf)
    shutil.chown(conf_file, user='slurm', group='slurm')

    gpu_conf = ""
    for pid, part in cfg.instance_defs.items():
        if not part.gpu_count:
            continue
        driver_range = '0'
        if part.gpu_count > 1:
            driver_range = '[0-{}]'.format(part.gpu_count-1)

        gpu_conf += ("NodeName={}-[0-{}] Name=gpu File=/dev/nvidia{}\n"
                     .format(pid, part.max_node_count - 1, driver_range))
    if gpu_conf:
        (slurmdirs.etc/'gres.conf').write_text(gpu_conf)
# END install_cgroup_conf()


def install_meta_files():
    """ save config.yaml and download all scripts from metadata """
    cfg.save_config(dirs.scripts/'config.yaml')
    shutil.chown(dirs.scripts/'config.yaml', user='slurm', group='slurm')

    meta_entries = [
        ('suspend.py', 'slurm-suspend'),
        ('resume.py', 'slurm-resume'),
        ('slurmsync.py', 'slurmsync'),
        ('util.py', 'util-script'),
        ('setup.py', 'setup-script'),
        ('startup.sh', 'startup-script'),
        ('custom-compute-install', 'custom-compute-install'),
        ('custom-controller-install', 'custom-controller-install'),
    ]

    def install_metafile(filename, metaname):
        text = util.get_metadata('attributes/' + metaname)
        if not text:
            return
        path = dirs.scripts/filename
        path.write_text(text)
        path.chmod(0o755)
        shutil.chown(path, user='slurm', group='slurm')

    with ThreadPoolExecutor() as exe:
        exe.map(lambda x: install_metafile(*x), meta_entries)

# END install_meta_files()


def prepare_network_mounts(hostname, instance_type):
    """ Prepare separate lists of cluster-internal and external mounts for the
    given host instance, returning (external_mounts, internal_mounts)
    """
    log.info("Set up network storage")

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
    # seed the non-controller mounts with the default controller mounts
    mounts = {
        path: util.Config(CONTROL_NFS, local_mount=path, remote_mount=path)
        for path in default_mounts
    }

    # convert network_storage list of mounts to dict of mounts,
    #   local_mount as key
    def listtodict(mountlist):
        return {Path(d['local_mount']).resolve(): d for d in mountlist}

    # On non-controller instances, entries in network_storage could overwrite
    # default exports from the controller. Be careful, of course
    mounts.update(listtodict(cfg.network_storage))

    if instance_type == 'compute':
        pid = util.get_pid(hostname)
        mounts.update(listtodict(cfg.instance_defs[pid].network_storage))
    else:
        # login_network_storage is mounted on controller and login instances
        mounts.update(listtodict(cfg.login_network_storage))

    # filter mounts into two dicts, cluster-internal and external mounts, and
    # return both. (external_mounts, internal_mounts)
    def internal_mount(mount):
        return mount[1].server_ip == CONTROL_MACHINE

    def partition(pred, coll):
        """ filter into 2 lists based on pred returning True or False 
            returns ([False], [True])
        """
        return reduce(
            lambda acc, el: acc[pred(el)].append(el) or acc,
            coll, ([], [])
        )

    return tuple(map(dict, partition(internal_mount, mounts.items())))
# END prepare_network_mounts


def setup_network_storage():
    """ prepare network fs mounts and add them to fstab """

    global mounts
    ext_mounts, int_mounts = prepare_network_mounts(cfg.hostname,
                                                    cfg.instance_type)
    mounts = ext_mounts
    if cfg.instance_type != 'controller':
        mounts.update(int_mounts)

    # Determine fstab entries and write them out
    fstab_entries = []
    for local_mount, mount in mounts.items():
        remote_mount = mount.remote_mount
        fs_type = mount.fs_type
        server_ip = mount.server_ip

        # do not mount controller mounts to itself
        if server_ip == CONTROL_MACHINE and cfg.instance_type == 'controller':
            continue

        log.info("Setting up mount ({}) {}{} to {}".format(
            fs_type, server_ip+':' if fs_type != 'gcsfuse' else "",
            remote_mount, local_mount))

        local_mount.mkdirp()

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
            remote_mount = Path(remote_mount).resolve()
            fstab_entries.append(
                "{0}:{1}    {2}     {3}      {4}  0 0"
                .format(server_ip, remote_mount, local_mount,
                        fs_type, ','.join(mount_options)))

    for mount in mounts:
        Path(mount).mkdirp()
    with open('/etc/fstab', 'a') as f:
        f.write('\n')
        for entry in fstab_entries:
            f.write(entry)
            f.write('\n')
# END setup_network_storage()


def mount_fstab():
    """ Wait on each mount, then make sure all fstab is mounted """
    global mounts

    def mount_path(path):
        while not os.path.ismount(path):
            log.info(f"Waiting for {path} to be mounted")
            util.run(f"mount {path}", wait=5)

    with ThreadPoolExecutor() as exe:
        exe.map(mount_path, mounts.keys())

    util.run("mount -a", wait=1)
# END mount_external


def setup_nfs_exports():
    """ nfs export all needed directories """
    # The controller only needs to set up exports for cluster-internal mounts
    # switch the key to remote mount path since that is what needs exporting
    _, con_mounts = prepare_network_mounts(cfg.hostname, cfg.instance_type)
    con_mounts = {m.remote_mount: m for m in con_mounts.values()}
    for pid, _ in cfg.instance_defs.items():
        # get internal mounts for each partition by calling
        # prepare_network_mounts as from a node in each partition
        _, part_mounts = prepare_network_mounts(f'{pid}-n', 'compute')
        part_mounts = {m.remote_mount: m for m in part_mounts.values()}
        con_mounts.update(part_mounts)

    # export path if corresponding selector boolean is True
    exports = []
    for path in con_mounts:
        Path(path).mkdirp()
        util.run(rf"sed -i '\#{path}#d' /etc/exports")
        exports.append(f"{path}  *(rw,no_subtree_check,no_root_squash)")

    exportsd = Path('/etc/exports.d')
    exportsd.mkdirp()
    with (exportsd/'slurm.exports').open('w') as f:
        f.write('\n')
        f.write('\n'.join(exports))
    util.run("exportfs -a")
# END setup_nfs_exports()


def setup_secondary_disks():
    """ Format and mount secondary disk """
    util.run(
        "sudo mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb")
    with open('/etc/fstab', 'a') as f:
        f.write(
            "\n/dev/sdb     {0}     ext4    discard,defaults,nofail     0 2"
            .format(dirs.secdisk))

# END setup_secondary_disks()


def setup_sync_cronjob():
    """ Create cronjob for running slurmsync.py """
    util.run("crontab -u slurm -", input=(
        f"*/1 * * * * {dirs.scripts}/slurmsync.py\n"))

# END setup_sync_cronjob()


def setup_jwt_key():
    jwt_key = slurmdirs.state/'jwt_hs256.key'

    if cfg.jwt_key:
        with (jwt_key).open('w') as f:
            f.write(cfg.jwt_key)
    else:
        util.run("dd if=/dev/urandom bs=32 count=1 >"+str(jwt_key), shell=True)

    util.run(f"chown -R slurm:slurm {jwt_key}")
    jwt_key.chmod(0o400)


def setup_slurmd_cronjob():
    """ Create cronjob for keeping slurmd service up """
    util.run(
        "crontab -u root -", input=(
            "*/2 * * * * "
            "if [ `systemctl status slurmd | grep -c inactive` -gt 0 ]; then "
            "mount -a; "
            "systemctl restart munge; "
            "systemctl restart slurmd; "
            "fi\n"
        ))
# END setup_slurmd_cronjob()


def setup_nss_slurm():
    """ install and configure nss_slurm """
    # setup nss_slurm
    Path('/var/spool/slurmd').mkdirp()
    util.run("ln -s {}/lib/libnss_slurm.so.2 /usr/lib64/libnss_slurm.so.2"
             .format(dirs.prefix))
    util.run(
        r"sed -i 's/\(^\(passwd\|group\):\s\+\)/\1slurm /g' /etc/nsswitch.conf"
    )
# END setup_nss_slurm()


def configure_dirs():

    for p in dirs.values():
        p.mkdirp()
    shutil.chown(dirs.slurm, user='slurm', group='slurm')
    shutil.chown(dirs.scripts, user='slurm', group='slurm')

    for p in slurmdirs.values():
        p.mkdirp()
        shutil.chown(p, user='slurm', group='slurm')

    (dirs.scripts/'etc').symlink_to(slurmdirs.etc)
    shutil.chown(dirs.scripts/'etc', user='slurm', group='slurm')

    (dirs.scripts/'log').symlink_to(slurmdirs.log)
    shutil.chown(dirs.scripts/'log', user='slurm', group='slurm')


def setup_controller():
    """ Run controller setup """
    expand_instance_templates()
    install_cgroup_conf()
    install_slurm_conf()
    install_slurmdbd_conf()
    setup_jwt_key()
    util.run("create-munge-key -f")
    util.run("systemctl restart munge")

    if cfg.controller_secondary_disk:
        setup_secondary_disks()
    setup_network_storage()
    mount_fstab()

    try:
        util.run(str(dirs.scripts/'custom-controller-install'))
    except Exception:
        # Ignore blank files with no shell magic.
        pass

    if not cfg.cloudsql:
        cnfdir = Path('/etc/my.cnf.d')
        if not cnfdir.exists():
            cnfdir = Path('/etc/mysql/conf.d')
        (cnfdir/'mysql_slurm.cnf').write_text("""
[mysqld]
bind-address = 127.0.0.1
""")
        util.run('systemctl enable mariadb')
        util.run('systemctl start mariadb')

        mysql = "mysql -u root -e"
        util.run(
            f"""{mysql} "create user 'slurm'@'localhost'";""")
        util.run(
            f"""{mysql} "grant all on slurm_acct_db.* TO 'slurm'@'localhost'";""")
        util.run(
            f"""{mysql} "grant all on slurm_acct_db.* TO 'slurm'@'{CONTROL_MACHINE}'";""")

    util.run("systemctl enable slurmdbd")
    util.run("systemctl start slurmdbd")

    # Wait for slurmdbd to come up
    time.sleep(5)

    sacctmgr = f"{dirs.prefix}/bin/sacctmgr -i"
    util.run(f"{sacctmgr} add cluster {cfg.cluster_name}")

    util.run("systemctl enable slurmctld")
    util.run("systemctl start slurmctld")

    util.run("systemctl enable slurmrestd")
    util.run("systemctl start slurmrestd")

    # Export at the end to signal that everything is up
    util.run("systemctl enable nfs-server")
    util.run("systemctl start nfs-server")

    setup_nfs_exports()
    setup_sync_cronjob()

    log.info("Done setting up controller")
    pass


def setup_login():
    """ run login node setup """
    setup_network_storage()
    mount_fstab()
    util.run("systemctl restart munge")

    try:
        util.run(str(dirs.scripts/'custom-compute-install'))
    except Exception:
        # Ignore blank files with no shell magic.
        pass
    log.info("Done setting up login")


def setup_compute():
    """ run compute node setup """
    setup_nss_slurm()
    setup_network_storage()
    mount_fstab()

    pid = util.get_pid(cfg.hostname)
    if (not cfg.instance_defs[pid].image_hyperthreads and
            shutil.which('google_mpi_tuning')):
        util.run("google_mpi_tuning --nosmt")
    if cfg.instance_defs[pid].gpu_count:
        retries = n = 50
        while util.run("nvidia-smi").returncode != 0 and n > 0:
            n -= 1
            log.info(f"Nvidia driver not yet loaded, try {retries-n}")
            time.sleep(5)

    try:
        util.run(str(dirs.scripts/'custom-compute-install'))
    except Exception:
        # Ignore blank files with no shell magic.
        pass

    setup_slurmd_cronjob()
    util.run("systemctl restart munge")
    util.run("systemctl enable slurmd")
    util.run("systemctl start slurmd")

    log.info("Done setting up compute")


def main():

    start_motd()
    configure_dirs()
    install_meta_files()

    # call the setup function for the instance type
    setup = dict.get(
        {
            'controller': setup_controller,
            'compute': setup_compute,
            'login': setup_login
        },
        cfg.instance_type,
        lambda: log.fatal(f"Unknown instance type: {cfg.instance_type}")
    )
    setup()

    end_motd()
# END main()


if __name__ == '__main__':
    main()
