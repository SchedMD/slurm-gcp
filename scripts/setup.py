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


# first try to import util normally
util_spec = importlib.util.find_spec('util')
if not util_spec:
    # prefer /tmp/util.py
    UTIL_FILE = Path('/tmp/util.py')
    if not UTIL_FILE.exists():
        # get util.py from metadata
        print(f"{UTIL_FILE} does not exist, checking in metadata")
        UTIL_URL = 'http://metadata.google.internal/computeMetadata/v1/instance/attributes/util-script'
        try:
            resp = requests.get(UTIL_URL, headers={'Metadata-Flavor': 'Google'})
            resp.raise_for_status()
            UTIL_FILE.write_text(resp.text)
        except requests.exceptions.RequestException:
            print("util.py script not found in metadata")
            sys.exit(1)
    util_spec = importlib.util.spec_from_file_location('util', UTIL_FILE)

util = importlib.util.module_from_spec(util_spec)
sys.modules[util_spec.name] = util
util_spec.loader.exec_module(util)

# import into local namespace
cd = util.cd
NSDict = util.NSDict
run = util.run
get_pid = util.get_pid
get_metadata = util.get_metadata
ensure_execute = util.ensure_execute

# monkey patch?
Path.mkdirp = partialmethod(Path.mkdir, parents=True, exist_ok=True)

util.config_root_logger(logfile='/slurm/scripts/setup.log')
log = logging.getLogger(Path(__file__).name)
sys.excepthook = util.handle_exception

# get setup config from metadata
config_yaml = yaml.safe_load(get_metadata('attributes/config'))
cfg = util.Config.new_config(config_yaml)

# load all directories as Paths into a dict-like namespace
dirs = NSDict({n: Path(p) for n, p in dict.items({
    'home': '/home',
    'apps': '/apps',
    'scripts': '/slurm/scripts',
    'slurm': '/slurm',
    'prefix': os.environ.get('SLURM_PREFIX', None) or '/usr/local',
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

RESUME_TIMEOUT = 400
SUSPEND_TIMEOUT = 400

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

    run("wall -n '*** Slurm {} setup complete ***'".format(cfg.instance_type))
    if cfg.instance_type != 'controller':
        run("""wall -n '
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
            template_resp = ensure_execute(
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
            list_resp = ensure_execute(
                compute.machineTypes().aggregatedList(
                    project=cfg.project, filter=filter))

            if 'items' in list_resp:
                zone_types = list_resp['items']
                for k, v in zone_types.items():
                    if part.region in k and 'machineTypes' in v:
                        type_resp = v['machineTypes'][0]
                        break
        else:
            type_resp = ensure_execute(
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
    conf_resp = get_metadata('attributes/slurm_conf_tpl')
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
                 f"CPUs={machine['cpus']} "
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
        if part.exclusive or part.tpu_type:
            conf += " Oversubscribe=Exclusive"
        if part.tpu_type:
            conf += " MaxNodes=1"

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

    conf_resp = get_metadata('attributes/slurmdbd_conf_tpl')
    conf = conf_resp.format(**conf_options)

    conf_file = slurmdirs.etc/'slurmdbd.conf'
    conf_file.write_text(conf)
    shutil.chown(conf_file, user='slurm', group='slurm')
    conf_file.chmod(0o600)
# END install_slurmdbd_conf()


def install_cgroup_conf():
    """ install cgroup.conf """
    conf = get_metadata('attributes/cgroup_conf_tpl')

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
        text = get_metadata('attributes/' + metaname)
        if not text:
            return
        path = dirs.scripts/filename
        path.write_text(text)
        path.chmod(0o755)
        shutil.chown(path, user='slurm', group='slurm')

    with ThreadPoolExecutor() as exe:
        exe.map(lambda x: install_metafile(*x), meta_entries)

# END install_meta_files()


def prepare_network_mounts(nodename, instance_type):
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
        pid = get_pid(nodename)
        mounts.update(listtodict(cfg.instance_defs[pid].network_storage))
    else:
        # login_network_storage is mounted on controller and login instances
        mounts.update(listtodict(cfg.login_network_storage))

    def internal_mount(mount):
        return mount.server_ip == CONTROL_MACHINE
    internal = {k:v for k, v in mounts.items() if internal_mount(v)}
    external = {k:v for k, v in mounts.items() if not internal_mount(v)}

    return external, internal
# END prepare_network_mounts


def setup_network_storage():
    """ prepare network fs mounts and add them to fstab """

    global mounts
    ext_mounts, int_mounts = prepare_network_mounts(cfg.nodename,
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
            run(f"mount {path}", wait=5)

    with ThreadPoolExecutor() as exe:
        exe.map(mount_path, mounts.keys())

    run("mount -a", wait=1)
# END mount_external


def setup_nfs_exports():
    """ nfs export all needed directories """
    # The controller only needs to set up exports for cluster-internal mounts
    # switch the key to remote mount path since that is what needs exporting
    _, con_mounts = prepare_network_mounts(cfg.nodename, cfg.instance_type)
    con_mounts = {Path(m.remote_mount).resolve(): m for m in con_mounts.values()}
    for pid, _ in cfg.instance_defs.items():
        # get internal mounts for each partition by calling
        # prepare_network_mounts as from a node in each partition
        _, part_mounts = prepare_network_mounts(f'{pid}-n', 'compute')
        part_mounts = {Path(m.remote_mount).resolve(): m for m in part_mounts.values()}
        con_mounts.update(part_mounts)


    # Always export scripts dir
    if dirs.scripts not in con_mounts:
        con_mounts[dirs.scripts] = None

    exports = []
    for path in con_mounts:
        path.mkdirp()
        run(rf"sed -i '\#{path}#d' /etc/exports")
        exports.append(f"{path}  *(rw,no_subtree_check,no_root_squash)")

    exportsd = Path('/etc/exports.d')
    exportsd.mkdirp()
    with (exportsd/'slurm.exports').open('w') as f:
        f.write('\n')
        f.write('\n'.join(exports))
    run("exportfs -a")
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
    run("crontab -u slurm -", input=(
        f"*/1 * * * * {dirs.scripts}/slurmsync.py\n"))

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
    ))
# END setup_slurmd_cronjob()


def setup_nss_slurm(prefix=dirs.prefix):
    """ install and configure nss_slurm """
    # setup nss_slurm
    Path('/var/spool/slurmd').mkdirp()
    run(f"ln -s {prefix}/lib/libnss_slurm.so.2 /usr/lib64/libnss_slurm.so.2")
    run(r"sed -i 's/\(^\(passwd\|group\):\s\+\)/\1slurm /g' /etc/nsswitch.conf")
# END setup_nss_slurm()


def create_users():
    """ Create users, hide errors (might already exist) """
    run("groupadd munge -g 980", stderr=DEVNULL)
    run("useradd -m -c MungeUser -d /var/run/munge -r munge -u 980 -g 980",
        stderr=DEVNULL)

    run("groupadd slurm -g 981", stderr=DEVNULL)
    run("useradd -m -c SlurmUser -d /var/lib/slurm -r slurm -u 981 -g 981",
        stderr=DEVNULL)

    run("groupadd slurmrestd -g 982", stderr=DEVNULL)
    run("useradd -m -c Slurmrestd -d /var/lib/slurmrestd -r slurmrestd -u 982 -g 982",
        stderr=DEVNULL)


def configure_dirs():

    for p in dirs.values():
        p.mkdirp()
    shutil.chown(dirs.slurm, user='slurm', group='slurm')
    shutil.chown(dirs.scripts, user='slurm', group='slurm')

    for p in slurmdirs.values():
        p.mkdirp()
        shutil.chown(p, user='slurm', group='slurm')

    etc_link = dirs.scripts/'etc'
    if not etc_link.exists():
        etc_link.symlink_to(slurmdirs.etc)
        shutil.chown(etc_link, user='slurm', group='slurm')

    log_link = dirs.scripts/'log'
    if not log_link.exists():
        log_link.symlink_to(slurmdirs.log)
        shutil.chown(log_link, user='slurm', group='slurm')


def setup_controller():
    """ Run controller setup """
    expand_instance_templates()
    install_cgroup_conf()
    install_slurm_conf()
    install_slurmdbd_conf()
    setup_jwt_key()
    run("create-munge-key -f")
    run("systemctl restart munge")

    if cfg.controller_secondary_disk:
        setup_secondary_disks()
    setup_network_storage()
    mount_fstab()

    try:
        run(str(dirs.scripts/'custom-controller-install'))
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
        run('systemctl enable mariadb')
        run('systemctl start mariadb')

        mysql = "mysql -u root -e"
        run(f"""{mysql} "create user 'slurm'@'localhost'";""")
        run(f"""{mysql} "grant all on slurm_acct_db.* TO 'slurm'@'localhost'";""")
        run(f"""{mysql} "grant all on slurm_acct_db.* TO 'slurm'@'{CONTROL_MACHINE}'";""")

    run("systemctl enable slurmdbd")
    run("systemctl start slurmdbd")

    # Wait for slurmdbd to come up
    time.sleep(5)

    sacctmgr = f"{dirs.prefix}/bin/sacctmgr -i"
    run(f"{sacctmgr} add cluster {cfg.cluster_name}")

    run("systemctl enable slurmctld")
    run("systemctl start slurmctld")

    run("systemctl enable slurmrestd")
    run("systemctl start slurmrestd")

    # Export at the end to signal that everything is up
    run("systemctl enable nfs-server")
    run("systemctl start nfs-server")

    setup_nfs_exports()
    setup_sync_cronjob()

    log.info("Done setting up controller")
    pass


def setup_login():
    """ run login node setup """
    setup_network_storage()
    mount_fstab()
    run("systemctl restart munge")

    try:
        run(str(dirs.scripts/'custom-compute-install'))
    except Exception:
        # Ignore blank files with no shell magic.
        pass
    log.info("Done setting up login")


def setup_compute():
    """ run compute node setup """
    setup_nss_slurm()
    setup_network_storage()
    mount_fstab()

    pid = get_pid(cfg.nodename)
    if (not cfg.instance_defs[pid].image_hyperthreads and
            shutil.which('google_mpi_tuning')):
        run("google_mpi_tuning --nosmt")
    if cfg.instance_defs[pid].gpu_count:
        retries = n = 50
        while run("nvidia-smi").returncode != 0 and n > 0:
            n -= 1
            log.info(f"Nvidia driver not yet loaded, try {retries-n}")
            time.sleep(5)

    try:
        run(str(dirs.scripts/'custom-compute-install'))
    except Exception:
        # Ignore blank files with no shell magic.
        pass

    setup_slurmd_cronjob()
    run("systemctl restart munge")
    run("systemctl enable slurmd")
    run("systemctl start slurmd")

    log.info("Done setting up compute")


def setup_modules(modulefiles):
    """ Add /apps/modulefiles as environment module dir """
    url = 'https://github.com/TACC/Lmod.git'
    prefix = Path('/opt')
    src = prefix/'lmod/src'
    lmod = prefix/'lmod/lmod'
    run(f"git clone --single-branch --depth 1 {url} {src}")

    modulespath = lmod/'init/modulespath'
    with cd(src):
        run(f"./configure --prefix={prefix} --with-ModulePathInit={modulespath}")
        run("make install", stdout=DEVNULL)
        lmodsh = Path('/etc/profile.d/z00_lmod.sh')
        if lmodsh.exists():
            lmodsh.unlink()
        lmodsh.symlink_to(lmod/'init/bash')

    modulespath.write_text(f"{modulefiles}")


def setup_compute_tpu():
    #run("apt-get update")
    run("apt-get install -y libmunge-dev munge nfs-common hwloc")
    module_depend = (
        'lua5.3',
        'lua-bit32:amd64',
        'lua-posix:amd64',
        'lua-posix-dev',
        'liblua5.3-0:amd64',
        'liblua5.3-dev:amd64',
        'tcl',
        'tcl-dev',
        'tcl8.6',
        'tcl8.6-dev:amd64',
        'libtcl8.6:amd64',
    )
    run("apt-get install -y {}".format(' '.join(module_depend)))
    modulefiles = Path('/apps/modulefiles')
    setup_modules(modulefiles)
    slurm_module = modulefiles/'slurm'
    slurm_module.mkdir(parents=True, exist_ok=True)

    slurm_prefix = Path('/opt/slurm')
    (slurm_module/'slurm.lua').write_text(f"""
slurm_prefix={slurm_prefix}
prepend_path("PATH", slurm_prefix.."/bin")
prepend_path("LD_LIBRARY_PATH", slurm_prefix.."/lib")
prepend_path("MANPATH", slurm_prefix.."/share/man")
""")

    setup_nss_slurm(slurm_prefix)
    setup_network_storage()
    mount_fstab()

    # add nonstandard slurm prefix to bash profile PATH
    # source this in salloc or batch script to access slurm client commands
    Path('/etc/profile.d/slurm.sh').write_text(f"""
S_PATH={slurm_prefix}
PATH=$S_PATH/bin:$S_PATH/sbin:$PATH
""")

    rank = int(get_metadata('attributes/agent-worker-number') or 0)
    #run("rm -f /usr/local/sbin/slurmd")

    if rank == 0:
        setup_slurmd_cronjob()
        run("systemctl restart munge")
        override = Path('/etc/systemd/system/slurmd.service.d/conf-server.conf')
        override.parent.mkdirp()
        override.write_text(f"""
[Service]
Environment=SLURMD_OPTIONS='--conf-server={CONTROL_MACHINE}:6820 -N{cfg.nodename}'
""")
        run("systemctl daemon-reload")
        run(f"systemctl enable {slurm_prefix}/etc/slurmd.service")
        run("systemctl start slurmd")
    else:
        log.info("Not starting slurmd, not rank 0 tpu-vm")

    try:
        run(str(dirs.scripts/'custom-compute-install'))
    except Exception:
        # Ignore blank files with no shell magic.
        pass

    log.info("Done setting up compute-tpu")


def main():
        # nss_slurm?
        # gets linked right if prefix is right in setup.py
        # need to setup nss_slurm.conf thought because the nodename is different.

    start_motd()
    create_users()
    configure_dirs()
    install_meta_files()

    # call the setup function for the instance type
    instance_type = cfg.instance_type
    if instance_type == 'compute' and get_metadata('attributes/tpu-vm'):
        instance_type = 'compute-tpu'
        log.info("Detected a tpu-vm instance, running alternate compute setup")
    setup = dict.get(
        {
            'controller': setup_controller,
            'compute': setup_compute,
            'compute-tpu': setup_compute_tpu,
            'login': setup_login
        },
        instance_type,
        lambda: log.fatal(f"Unknown instance type: {instance_type}")
    )
    setup()

    end_motd()
# END main()


if __name__ == '__main__':
    main()
