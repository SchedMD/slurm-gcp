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

import datetime
import importlib
import itertools as it
import logging
import os
import shutil
import socket
import sys
import time
import threading
import urllib.request
from pathlib import Path
from subprocess import DEVNULL

import googleapiclient.discovery
import requests
import yaml


# get util.py from metadata
UTIL_FILE = Path('/tmp/util.py')
try:
    resp = requests.get('http://metadata.google.internal/computeMetadata/v1/instance/attributes/util_script',
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

util.config_root_logger()
log = logging.getLogger(Path(__file__).name)

# get setup config from metadata
config_yaml = yaml.safe_load(util.get_metadata('attributes/config'))
if not util.get_metadata('attributes/terraform'):
    config_yaml = yaml.safe_load(config_yaml)
cfg = util.Config.new_config(config_yaml)

HOME_DIR = Path('/home')
APPS_DIR = Path('/apps')
CURR_SLURM_DIR = APPS_DIR/'slurm/current'
MUNGE_DIR = Path('/etc/munge')
SLURM_LOG = Path('/var/log/slurm')

SEC_DISK_DIR = Path('/mnt/disks/sec')
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


def add_slurm_user():

    util.run("useradd -m -c SlurmUser -d /var/lib/slurm -U -r slurm")
# END add_slurm_user()


def setup_modules():

    appsmfs = Path('/apps/modulefiles')

    with open('/usr/share/Modules/init/.modulespath', 'r+') as dotmp:
        if str(appsmfs) not in dotmp.read():
            if cfg.instance_type == 'controller' and not appsmfs.is_dir():
                appsmfs.mkdir(parents=True)
            # after read, file cursor is at end of file
            dotmp.write(f'\n{appsmfs}\n')
# END setup_modules


def start_motd():

    msg = MOTD_HEADER + """
*** Slurm is currently being installed/configured in the background. ***
A terminal broadcast will announce when installation and configuration is
complete.

Partitions will be marked down until the compute image has been created.
For instances with gpus attached, it could take ~10 mins after the controller
has finished installing.

"""

    if cfg.instance_type != "controller":
        msg += """/home on the controller will be mounted over the existing /home.
Any changes in /home will be hidden. Please wait until the installation is
complete before making changes in your home directory.

"""

    with open('/etc/motd', 'w') as f:
        f.write(msg)
# END start_motd()


def end_motd(broadcast=True):

    with open('/etc/motd', 'w') as f:
        f.write(MOTD_HEADER)

    if not broadcast:
        return

    util.run("wall -n '*** Slurm {} daemon installation complete ***'"
             .format(cfg.instance_type))

    if cfg.instance_type != 'controller':
        util.run("""wall -n '
/home on the controller was mounted over the existing /home.
Either log out and log back in or cd into ~.
'""")
# END start_motd()


def have_gpus(hostname):

    pid = util.get_pid(hostname)
    return cfg.partitions[pid].gpu_count > 0
# END have_gpus()


def install_slurmlog_conf():
    """ Install fluentd config for slurm logs """

    slurmlog_config = util.get_metadata('attributes/fluentd_conf_tpl')
    if slurmlog_config:
        Path('/etc/google-fluentd/config.d/slurmlogs.conf').write_text(
            slurmlog_config)


def install_packages():

    # install stackdriver monitoring and logging
    add_mon_script = Path('/tmp/add-monitoring-agent-repo.sh')
    add_mon_url = f'https://dl.google.com/cloudagents/{add_mon_script.name}'
    urllib.request.urlretrieve(add_mon_url, add_mon_script)
    util.run(f"bash {add_mon_script}")
    util.run("yum install -y stackdriver-agent")

    add_log_script = Path('/tmp/install-logging-agent.sh')
    add_log_url = f'https://dl.google.com/cloudagents/{add_log_script.name}'
    urllib.request.urlretrieve(add_log_url, add_log_script)
    util.run(f"bash {add_log_script}")
    install_slurmlog_conf()

    util.run("systemctl enable stackdriver-agent google-fluentd")
    util.run("systemctl start stackdriver-agent google-fluentd")

    # install cuda if needed
    if cfg.instance_type == 'compute' and have_gpus(socket.gethostname()):
        util.run("yum -y install kernel-devel-$(uname -r) kernel-headers-$(uname -r)",
                 shell=True)
        repo = 'http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/cuda-rhel7.repo'
        util.run(f"yum-config-manager --add-repo {repo}")
        util.run("yum clean all")
        util.run("yum -y install nvidia-driver-latest-dkms cuda")
        util.run("yum -y install cuda-drivers")
        # Creates the device files
        util.run("nvidia-smi")
# END install_packages()


def setup_munge():

    munge_service_patch = Path('/usr/lib/systemd/system/munge.service')
    req_mount = (f"\nRequiresMountsFor={MUNGE_DIR}"
                 if cfg.instance_type != 'controller' else '')
    with munge_service_patch.open('w') as f:
        f.write(f"""
[Unit]
Description=MUNGE authentication service
Documentation=man:munged(8)
After=network.target
After=syslog.target
After=time-sync.target{req_mount}

[Service]
Type=forking
ExecStart=/usr/sbin/munged --num-threads=10
PIDFile=/var/run/munge/munged.pid
User=munge
Group=munge
Restart=on-abort

[Install]
WantedBy=multi-user.target
""")

    util.run("systemctl enable munge")

    if cfg.instance_type != 'controller':
        return

    if cfg.munge_key:
        with (MUNGE_DIR/'munge.key').open('w') as f:
            f.write(cfg.munge_key)

        util.run(f"chown -R munge: {MUNGE_DIR} /var/log/munge/")

        (MUNGE_DIR/'munge_key').chmod(0o400)
        MUNGE_DIR.chmod(0o700)
        Path('var/log/munge/').chmod(0o700)
    else:
        util.run('create-munge-key')
# END setup_munge ()


def start_munge():
    util.run("systemctl start munge")
# END start_munge()


def setup_nfs_exports():

    export_paths = (
        (HOME_DIR, not EXTERNAL_MOUNT_HOME),
        (APPS_DIR, not EXTERNAL_MOUNT_APPS),
        (MUNGE_DIR, not EXTERNAL_MOUNT_MUNGE),
        (SEC_DISK_DIR, cfg.controller_secondary_disk),
    )

    # export path if corresponding selector boolean is True
    for path in it.compress(*zip(*export_paths)):
        util.run(rf"sed -i '\#{path}#d' /etc/exports")
        with open('/etc/exports', 'a') as f:
            f.write(f"\n{path}  *(rw,no_subtree_check,no_root_squash)")

    util.run("exportfs -a")
# END setup_nfs_exports()


def expand_machine_type():

    machines = []
    compute = googleapiclient.discovery.build('compute', 'v1',
                                              cache_discovery=False)
    for part in cfg.partitions:
        machine = {'cpus': 1, 'memory': 1}
        try:
            type_resp = compute.machineTypes().get(
                project=cfg.project, zone=part.zone,
                machineType=part.machine_type).execute()
            if type_resp:
                machine['cpus'] = type_resp['guestCpus']

                # Because the actual memory on the host will be different than
                # what is configured (e.g. kernel will take it). From
                # experiments, about 16 MB per GB are used (plus about 400 MB
                # buffer for the first couple of GB's. Using 30 MB to be safe.
                gb = type_resp['memoryMb'] // 1024
                machine['memory'] = type_resp['memoryMb'] - (400 + (gb * 30))

        except Exception:
            log.exception("Failed to get MachineType '{}' from google api"
                          .format(part.machine_type))
        finally:
            machines.append(machine)

    return machines
# END expand_machine_type()


def install_slurm_conf():

    machines = expand_machine_type()

    if cfg.ompi_version:
        mpi_default = "pmi2"
    else:
        mpi_default = "none"

    conf_resp = util.get_metadata('attributes/slurm_conf_tpl')
    conf = conf_resp.format(**globals(), **locals())

    static_nodes = []
    for i, machine in enumerate(machines):
        part = cfg.partitions[i]
        static_range = ''
        if part.static_node_count:
            if part.static_node_count > 1:
                static_range = '{}-{}-[0-{}]'.format(
                    cfg.compute_node_prefix, i, part.static_node_count - 1)
            else:
                static_range = f"{cfg.compute_node_prefix}-{i}-0"

        cloud_range = ""
        if (part.max_node_count and
                (part.max_node_count != part.static_node_count)):
            cloud_range = "{}-{}-[{}-{}]".format(
                cfg.compute_node_prefix, i, part.static_node_count,
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

        # Partitions
        part_nodes = f'-{i}-[0-{part.max_node_count - 1}]'

        def_mem_per_cpu = max(100, machine['memory'] // machine['cpus'])

        conf += ("PartitionName={} Nodes={}-compute{} MaxTime=INFINITE "
                 "State=UP DefMemPerCPU={} LLN=yes"
                 .format(part.name, cfg.cluster_name, part_nodes,
                         def_mem_per_cpu))

        # First partition specified is treated as the default partition
        if i == 0:
            conf += " Default=YES"
        conf += "\n\n"

    if len(static_nodes):
        conf += "\nSuspendExcNodes={}\n".format(','.join(static_nodes))

    etc_dir = CURR_SLURM_DIR/'etc'
    if not etc_dir.exists():
        etc_dir.mkdir(parents=True)
    with (etc_dir/'slurm.conf').open('w') as f:
        f.write(conf)
# END install_slurm_conf()


def install_slurmdbd_conf():
    if cfg.cloudsql:
        db_name = cfg.cloudsql['db_name']
        db_user = cfg.cloudsql['user']
        db_pass = cfg.cloudsql['password']
        db_host_str = cfg.cloudsql['server_ip'].split(':')
        db_host = db_host_str[0]
        db_port = db_host_str[1] if len(db_host_str) >= 2 else '3306'
    else:
        db_name = "slurm_acct_db"
        db_user = 'slurm'
        db_pass = '""'
        db_host = 'localhost'
        db_port = '3306'

    conf_resp = util.get_metadata('attributes/slurmdbd_conf_tpl')
    conf = conf_resp.format(**globals(), **locals())

    etc_dir = CURR_SLURM_DIR/'etc'
    if not etc_dir.exists():
        etc_dir.mkdir(parents=True)
    (etc_dir/'slurmdbd.conf').write_text(conf)
    (etc_dir/'slurmdbd.conf').chmod(0o600)

# END install_slurmdbd_conf()


def install_cgroup_conf():

    conf = util.get_metadata('attributes/cgroup_conf_tpl')

    etc_dir = CURR_SLURM_DIR/'etc'
    with (etc_dir/'cgroup.conf').open('w') as f:
        f.write(conf)

    gpu_parts = [(i, x) for i, x in enumerate(cfg.partitions)
                 if x.gpu_count]
    gpu_conf = ""
    for i, part in gpu_parts:
        driver_range = '0'
        if part.gpu_count > 1:
            driver_range = '[0-{}]'.format(part.gpu_count-1)

        gpu_conf += ("NodeName={}-{}-[0-{}] Name=gpu File=/dev/nvidia{}\n"
                     .format(cfg.compute_node_prefix, i,
                             part.max_node_count - 1, driver_range))
    if gpu_conf:
        with (etc_dir/'gres.conf').open('w') as f:
            f.write(gpu_conf)

# END install_cgroup_conf()


def install_meta_files():

    scripts_path = APPS_DIR/'slurm/scripts'
    if not scripts_path.exists():
        scripts_path.mkdir(parents=True)

    cfg.slurm_cmd_path = str(CURR_SLURM_DIR/'bin')
    cfg.log_dir = str(SLURM_LOG)

    cfg.save_config(scripts_path/'config.yaml')

    meta_files = [
        ('suspend.py', 'slurm_suspend'),
        ('resume.py', 'slurm_resume'),
        ('slurmsync.py', 'slurmsync'),
        ('util.py', 'util_script'),
        ('compute-shutdown', 'compute-shutdown'),
        ('custom-compute-install', 'custom-compute-install'),
        ('custom-controller-install', 'custom-controller-install'),
    ]

    for file_name, meta_name in meta_files:
        text = util.get_metadata('attributes/' + meta_name)
        if not text:
            continue

        with (scripts_path/file_name).open('w') as f:
            f.write(text)
        (scripts_path/file_name).chmod(0o755)

    util.run(
        "gcloud compute instances remove-metadata {} --zone={} --keys={}"
        .format(CONTROL_MACHINE, cfg.zone,
                ','.join([x[1] for x in meta_files])))

# END install_meta_files()


def install_slurm():

    src_path = APPS_DIR/'slurm/src'
    if not src_path.exists():
        src_path.mkdir(parents=True)

    with cd(src_path):
        use_version = ''
        if (cfg.slurm_version[0:2] == 'b:'):
            GIT_URL = 'https://github.com/SchedMD/slurm.git'
            use_version = cfg.slurm_version[2:]
            util.run(
                "git clone -b {0} {1} {0}".format(use_version, GIT_URL))
        else:
            file = 'slurm-{}.tar.bz2'.format(cfg.slurm_version)
            slurm_url = 'https://download.schedmd.com/slurm/' + file
            urllib.request.urlretrieve(slurm_url, src_path/file)

            use_version = util.run(f"tar -xvjf {file}", check=True,
                                   get_stdout=True).stdout.splitlines()[0][:-1]

    SLURM_PREFIX = APPS_DIR/'slurm'/use_version

    build_dir = src_path/use_version/'build'
    if not build_dir.exists():
        build_dir.mkdir(parents=True)

    with cd(build_dir):
        util.run("../configure --prefix={} --sysconfdir={}/etc"
                 .format(SLURM_PREFIX, CURR_SLURM_DIR), stdout=DEVNULL)
        util.run("make -j install", stdout=DEVNULL)
    with cd(build_dir/'contribs'):
        util.run("make -j install", stdout=DEVNULL)

    os.symlink(SLURM_PREFIX, CURR_SLURM_DIR)

    state_dir = APPS_DIR/'slurm/state'
    if not state_dir.exists():
        state_dir.mkdir(parents=True)
        util.run(f"chown -R slurm: {state_dir}")

    install_slurm_conf()
    install_slurmdbd_conf()
    install_cgroup_conf()
    install_meta_files()

# END install_slurm()


def install_slurm_tmpfile():

    run_dir = Path('/var/run/slurm')

    with open('/etc/tmpfiles.d/slurm.conf', 'w') as f:
        f.write(f"\nd {run_dir} 0755 slurm slurm -")

    if not run_dir.exists():
        run_dir.mkdir(parents=True)
    run_dir.chmod(0o755)

    util.run(f"chown slurm: {run_dir}")

# END install_slurm_tmpfile()


def install_controller_service_scripts():

    install_slurm_tmpfile()

    # slurmctld.service
    ctld_service = Path('/usr/lib/systemd/system/slurmctld.service')
    with ctld_service.open('w') as f:
        f.write("""
[Unit]
Description=Slurm controller daemon
After=network.target munge.service
ConditionPathExists={prefix}/etc/slurm.conf

[Service]
Type=forking
EnvironmentFile=-/etc/sysconfig/slurmctld
ExecStart={prefix}/sbin/slurmctld $SLURMCTLD_OPTIONS
ExecReload=/bin/kill -HUP $MAINPID
PIDFile=/var/run/slurm/slurmctld.pid

[Install]
WantedBy=multi-user.target
""".format(prefix=CURR_SLURM_DIR))

    ctld_service.chmod(0o644)

    # slurmdbd.service
    dbd_service = Path('/usr/lib/systemd/system/slurmdbd.service')
    with dbd_service.open('w') as f:
        f.write("""
[Unit]
Description=Slurm DBD accounting daemon
After=network.target munge.service
ConditionPathExists={prefix}/etc/slurmdbd.conf

[Service]
Type=forking
EnvironmentFile=-/etc/sysconfig/slurmdbd
ExecStart={prefix}/sbin/slurmdbd $SLURMDBD_OPTIONS
ExecReload=/bin/kill -HUP $MAINPID
PIDFile=/var/run/slurm/slurmdbd.pid

[Install]
WantedBy=multi-user.target
""".format(prefix=CURR_SLURM_DIR))

    dbd_service.chmod(0o644)

# END install_controller_service_scripts()


def install_compute_service_scripts():

    install_slurm_tmpfile()

    # slurmd.service
    slurmd_service = Path('/usr/lib/systemd/system/slurmd.service')
    with slurmd_service.open('w') as f:
        f.write("""
[Unit]
Description=Slurm node daemon
After=network.target munge.service home.mount apps.mount etc-munge.mount
ConditionPathExists={prefix}/etc/slurm.conf

[Service]
Type=forking
EnvironmentFile=-/etc/sysconfig/slurmd
ExecStart={prefix}/sbin/slurmd $SLURMD_OPTIONS
ExecReload=/bin/kill -HUP $MAINPID
PIDFile=/var/run/slurm/slurmd.pid
KillMode=process
LimitNOFILE=51200
LimitMEMLOCK=infinity
LimitSTACK=infinity

[Install]
WantedBy=multi-user.target
""".format(prefix=CURR_SLURM_DIR))

    slurmd_service.chmod(0o644)
    util.run('systemctl enable slurmd')

# END install_compute_service_scripts()


def setup_bash_profile():

    with open('/etc/profile.d/slurm.sh', 'w') as f:
        f.write("""
S_PATH={}
PATH=$PATH:$S_PATH/bin:$S_PATH/sbin
""".format(CURR_SLURM_DIR))

    if cfg.instance_type == 'compute' and have_gpus(socket.gethostname()):
        with open('/etc/profile.d/cuda.sh', 'w') as f:
            f.write("""
CUDA_PATH=/usr/local/cuda
PATH=$CUDA_PATH/bin${PATH:+:${PATH}}
LD_LIBRARY_PATH=$CUDA_PATH/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
""")

# END setup_bash_profile()


def setup_ompi_bash_profile():
    if not cfg.ompi_version:
        return
    with open(f'/etc/profile.d/ompi-{cfg.ompi_version}.sh', 'w') as f:
        f.write(f"PATH={APPS_DIR}/ompi/{cfg.ompi_version}/bin:$PATH")
# END setup_ompi_bash_profile()


def setup_logrotate():
    with open('/etc/logrotate.d/slurm', 'w') as f:
        f.write("""
##
# Slurm Logrotate Configuration
##
/var/log/slurm/*.log {
        compress
        missingok
        nocopytruncate
        nodelaycompress
        nomail
        notifempty
        noolddir
        rotate 5
        sharedscripts
        size=5M
        create 640 slurm root
        postrotate
                pkill -x --signal SIGUSR2 slurmctld
                pkill -x --signal SIGUSR2 slurmd
                pkill -x --signal SIGUSR2 slurmdbd
                exit 0
        endscript
}
""")
# END setup_logrotate()


def setup_network_storage():
    log.info("Set up network storage")

    global EXTERNAL_MOUNT_APPS
    global EXTERNAL_MOUNT_HOME
    global EXTERNAL_MOUNT_MUNGE

    EXTERNAL_MOUNT_APPS = False
    EXTERNAL_MOUNT_HOME = False
    EXTERNAL_MOUNT_MUNGE = False
    cifs_installed = False

    # create dict of mounts, local_mount: mount_info
    if cfg.instance_type == 'controller':
        ext_mounts = {}
    else:  # on non-controller instances, low priority mount these
        CONTROL_NFS = {
            'server_ip': CONTROL_MACHINE,
            'remote_mount': 'none',
            'local_mount': 'none',
            'fs_type': 'nfs',
            'mount_options': 'defaults,hard,intr',
        }
        ext_mounts = {
            HOME_DIR: dict(CONTROL_NFS, remote_mount=HOME_DIR,
                           local_mount=HOME_DIR),
            APPS_DIR: dict(CONTROL_NFS, remote_mount=APPS_DIR,
                           local_mount=APPS_DIR),
            MUNGE_DIR: dict(CONTROL_NFS, remote_mount=MUNGE_DIR,
                            local_mount=MUNGE_DIR),
        }

    # convert network_storage list of mounts to dict of mounts,
    #   local_mount as key
    def listtodict(mountlist):
        return {Path(d['local_mount']).resolve(): d for d in mountlist}

    ext_mounts.update(listtodict(cfg.network_storage))
    if cfg.instance_type == 'compute':
        pid = util.get_pid(socket.gethostname())
        ext_mounts.update(listtodict(cfg.partitions[pid].network_storage))
    else:
        ext_mounts.update(listtodict(cfg.login_network_storage))

    # Install lustre, cifs, and/or gcsfuse as needed and write mount to fstab
    fstab_entries = []
    for local_mount, mount in ext_mounts.items():
        remote_mount = mount['remote_mount']
        fs_type = mount['fs_type']
        server_ip = mount['server_ip']
        log.info("Setting up mount ({}) {}{} to {}".format(
            fs_type, server_ip+':' if fs_type != 'gcsfuse' else "",
            remote_mount, local_mount))
        if not local_mount.exists():
            local_mount.mkdir(parents=True)
        # Check if we're going to overlap with what's normally hosted on the
        # controller (/apps, /home, /etc/munge).
        # If so delete the entries pointing to the controller, and tell the
        # nodes.
        if local_mount == APPS_DIR:
            EXTERNAL_MOUNT_APPS = True
        elif local_mount == HOME_DIR:
            EXTERNAL_MOUNT_HOME = True
        elif local_mount == MUNGE_DIR:
            EXTERNAL_MOUNT_MUNGE = True

        lustre_path = Path('/sys/module/lustre')
        gcsf_path = Path('/etc/yum.repos.d/gcsfuse.repo')

        if fs_type == 'cifs' and not cifs_installed:
            util.run("sudo yum install -y cifs-utils")
            cifs_installed = True
        elif fs_type == 'lustre' and not lustre_path.exists():
            lustre_url = 'https://downloads.whamcloud.com/public/lustre/latest-release/el7.7.1908/client/RPMS/x86_64/'
            lustre_tmp = Path('/tmp/lustre')
            lustre_tmp.mkdir(parents=True)
            util.run('sudo yum update -y')
            util.run('sudo yum install -y wget libyaml')
            for rpm in ('kmod-lustre-client-2*.rpm', 'lustre-client-2*.rpm'):
                util.run(
                    f"wget -r -l1 --no-parent -A '{rpm}' '{lustre_url}' -P {lustre_tmp}")
            util.run(
                f"find {lustre_tmp} -name '*.rpm' -execdir rpm -ivh {{}} ';'")
            util.run(f"rm -rf {lustre_tmp}")
            util.run("modprobe lustre")
        elif fs_type == 'gcsfuse' and not gcsf_path.exists():
            with gcsf_path.open('a') as f:
                f.write("""
[gcsfuse]
name=gcsfuse (packages.cloud.google.com)
baseurl=https://packages.cloud.google.com/yum/repos/gcsfuse-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg""")
            util.run("sudo yum update -y")
            util.run("sudo yum install -y gcsfuse")

        mount_options = mount['mount_options']
        if fs_type == 'gcsfuse':
            if 'nonempty' not in mount['mount_options']:
                mount_options += ",nonempty"
            fstab_entries.append(
                "\n{0}   {1}     {2}     {3}     0 0"
                .format(remote_mount, local_mount, fs_type, mount_options))
        else:
            remote_mount = Path(remote_mount).resolve()
            fstab_entries.append(
                "\n{0}:{1}    {2}     {3}      {4}  0 0"
                .format(server_ip, remote_mount, local_mount,
                        fs_type, mount_options))

    with open('/etc/fstab', 'a') as f:
        for entry in fstab_entries:
            f.write(entry)
# END setup_network_storage()


def setup_secondary_disks():

    if not SEC_DISK_DIR.exists():
        SEC_DISK_DIR.mkdir(parents=True)
    util.run(
        "sudo mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb")
    with open('/etc/fstab', 'a') as f:
        f.write(
            "\n/dev/sdb     {0}     ext4    discard,defaults,nofail     0 2"
            .format(SEC_DISK_DIR))

# END setup_secondary_disks()


def mount_nfs_vols():

    mount_paths = (
        (HOME_DIR, EXTERNAL_MOUNT_HOME),
        (APPS_DIR, EXTERNAL_MOUNT_APPS),
        (MUNGE_DIR, EXTERNAL_MOUNT_MUNGE),
    )
    # compress yields values from the first arg that are matched with True
    # in the second arg. The result is the paths filtered by the booleans.
    # For non-controller instances, all three are always external nfs
    for path in it.compress(*zip(*mount_paths)):
        while not os.path.ismount(path):
            log.info(f"Waiting for {path} to be mounted")
            util.run(f"mount {path}", wait=5)
    util.run("mount -a", wait=1)

# END mount_nfs_vols()


# Tune the NFS server to support many mounts
def setup_nfs_threads():

    with open('/etc/sysconfig/nfs', 'a') as f:
        f.write("""
# Added by Google
RPCNFSDCOUNT=256
""")

# END setup_nfs_threads()


def setup_sync_cronjob():

    util.run("crontab -u slurm -", input=(
        f"*/1 * * * * {APPS_DIR}/slurm/scripts/slurmsync.py\n"))

# END setup_sync_cronjob()


def setup_slurmd_cronjob():
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


def create_compute_images():

    def create_compute_image(instance, partition):
        try:
            compute = googleapiclient.discovery.build('compute', 'v1',
                                                      cache_discovery=False)

            while True:
                resp = compute.instances().get(
                    project=cfg.project, zone=cfg.zone, fields="status",
                    instance=instance).execute()
                if resp['status'] == 'TERMINATED':
                    break
                log.info(f"waiting for {instance} to be stopped (status: {resp['status']})"
                         .format(instance=instance, status=resp['status']))
                time.sleep(30)

            log.info("Creating image of {}...".format(instance))
            ver = datetime.datetime.now().strftime('%Y-%m-%d-%H-%M-%S')
            util.run(f"gcloud compute images create "
                     f"{instance}-{ver} --source-disk {instance} "
                     f"--source-disk-zone {cfg.zone} --force "
                     f"--storage-location {partition.region} "
                     f"--family {instance}-family")

            util.run("{}/bin/scontrol update partitionname={} state=up"
                     .format(CURR_SLURM_DIR, partition.name))
        except Exception as e:
            log.exception(f"{instance} not found: {e}")

    threads = []
    for i, part in enumerate(cfg.partitions):
        instance = f"{cfg.compute_node_prefix}-{i}-image"
        thread = threading.Thread(target=create_compute_image,
                                  args=(instance, part))
        threads.append(thread)
        thread.start()

    for thread in threads:
        thread.join()

# END create_compute_image()


def setup_selinux():

    util.run('setenforce 0')
    with open('/etc/selinux/config', 'w') as f:
        f.write("""
SELINUX=permissive
SELINUXTYPE=targeted
""")
# END setup_selinux()


def install_ompi():

    if not cfg.ompi_version:
        return

    packages = ['autoconf',
                'flex',
                'gcc-c++',
                'libevent-devel',
                'libtool']
    util.run("yum install -y {}".format(' '.join(packages)))

    ompi_git = "https://github.com/open-mpi/ompi.git"
    ompi_path = APPS_DIR/'ompi'/cfg.ompi_version/'src'
    if not ompi_path.exists():
        ompi_path.mkdir(parents=True)
    util.run(f"git clone -b {cfg.ompi_version} {ompi_git} {ompi_path}")
    with cd(ompi_path):
        util.run("./autogen.pl", stdout=DEVNULL)

    build_path = ompi_path/'build'
    if not build_path.exists():
        build_path.mkdir(parents=True)
    with cd(build_path):
        util.run(
            f"../configure --prefix={APPS_DIR}/ompi/{cfg.ompi_version} "
            f"--with-pmi={APPS_DIR}/slurm/current --with-libevent=/usr "
            "--with-hwloc=/usr", stdout=DEVNULL)
        util.run("make -j install", stdout=DEVNULL)
# END install_ompi()


def remove_startup_scripts(hostname):

    cmd = "gcloud compute instances remove-metadata"
    common_keys = "startup-script,setup_script,util_script,config"
    controller_keys = (f"{common_keys},"
                       "slurm_conf_tpl,slurmdbd_conf_tpl,cgroup_conf_tpl")
    compute_keys = f"{common_keys},slurm_fluentd_log_tpl"

    # controller
    util.run(f"{cmd} {hostname} --zone={cfg.zone} --keys={controller_keys}")

    # logins
    for i in range(0, cfg.login_node_count):
        util.run("{} {}-login{} --zone={} --keys={}"
                 .format(cmd, cfg.cluster_name, i, cfg.zone, common_keys))
    # computes
    for i, part in enumerate(cfg.partitions):
        # partition compute image
        util.run(f"{cmd} {cfg.compute_node_prefix}-{i}-image "
                 f"--zone={cfg.zone} --keys={compute_keys}")
        if not part.static_node_count:
            continue
        for j in range(part.static_node_count):
            util.run("{} {}-{}-{} --zone={} --keys={}"
                     .format(cmd, cfg.compute_node_prefix, i, j,
                             part.zone, compute_keys))
# END remove_startup_scripts()


def setup_nss_slurm():

    # setup nss_slurm
    util.run("ln -s {}/lib/libnss_slurm.so.2 /usr/lib64/libnss_slurm.so.2"
             .format(CURR_SLURM_DIR))
    util.run(
        r"sed -i 's/\(^\(passwd\|group\):\s\+\)/\1slurm /g' /etc/nsswitch.conf"
    )
# END setup_nss_slurm()


def main():
    hostname = socket.gethostname()

    setup_selinux()

    start_motd()

    add_slurm_user()
    install_packages()
    setup_munge()
    setup_bash_profile()
    setup_ompi_bash_profile()
    setup_modules()

    if cfg.controller_secondary_disk and cfg.instance_type == 'controller':
        setup_secondary_disks()
    setup_network_storage()

    if not SLURM_LOG.exists():
        SLURM_LOG.mkdir(parents=True)
    shutil.chown(SLURM_LOG, user='slurm', group='slurm')

    if cfg.instance_type == 'controller':
        mount_nfs_vols()
        time.sleep(5)
        start_munge()
        install_slurm()
        install_ompi()

        try:
            util.run(str(APPS_DIR/'slurm/scripts/custom-controller-install'))
        except Exception:
            # Ignore blank files with no shell magic.
            pass

        install_controller_service_scripts()

        if not cfg.cloudsql:
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

        sacctmgr = f"{CURR_SLURM_DIR}/bin/sacctmgr -i"
        util.run(f"{sacctmgr} add cluster {cfg.cluster_name}")

        util.run("systemctl enable slurmctld")
        util.run("systemctl start slurmctld")
        setup_nfs_threads()
        # Export at the end to signal that everything is up
        util.run("systemctl enable nfs-server")
        util.run("systemctl start nfs-server")
        setup_nfs_exports()

        setup_sync_cronjob()

        # DOWN partitions until image is created.
        for part in cfg.partitions:
            util.run("{}/bin/scontrol update partitionname={} state=down"
                     .format(CURR_SLURM_DIR, part.name))

        create_compute_images()
        remove_startup_scripts(hostname)
        log.info("Done installing controller")
    elif cfg.instance_type == 'compute':
        install_compute_service_scripts()
        mount_nfs_vols()
        start_munge()
        setup_nss_slurm()
        setup_slurmd_cronjob()

        try:
            util.run(str(APPS_DIR/'slurm/scripts/custom-compute-install'))
        except Exception:
            # Ignore blank files with no shell magic.
            pass

        if hostname.endswith('-image'):
            end_motd(False)
            util.run("sync")
            util.run(f"gcloud compute instances stop {hostname} "
                     f"--zone {cfg.zone} --quiet")
        else:
            util.run("systemctl start slurmd")

    else:  # login nodes
        mount_nfs_vols()
        start_munge()

        try:
            util.run(str(APPS_DIR/"slurm/scripts/custom-compute-install"))
        except Exception:
            # Ignore blank files with no shell magic.
            pass

    setup_logrotate()

    end_motd()

# END main()


if __name__ == '__main__':
    main()
