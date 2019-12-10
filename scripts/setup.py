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
import os
import shlex
import shutil
import socket
import subprocess
import sys
import time
import urllib.request
from contextlib import contextmanager
from pathlib import Path

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

# get setup config from metadata
cfg = util.Config.new_config(
    yaml.safe_load(yaml.safe_load(util.get_metadata('attributes/config'))))

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

    SLURM_UID = str(992)
    subprocess.call(shlex.split("groupadd -g {} slurm".format(SLURM_UID)))
    subprocess.call(shlex.split(
        "useradd -m -c 'SLURM Workload Manager' -d /var/lib/slurm "
        "-u {} -g slurm -s /bin/bash slurm".format(SLURM_UID)))
# END add_slurm_user()


def setup_modules():

    appsmfs = Path('/apps/modulefiles')

    with open('/usr/share/Modules/init/.modulespath', 'r+') as dotmp:
        if str(appsmfs) not in dotmp.read():
            if cfg.instance_type != 'controller' and not appsmfs.is_dir():
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

    subprocess.call(shlex.split(
        "wall -n '*** Slurm {} daemon installation complete ***'"
        .format(cfg.instance_type)))

    if cfg.instance_type != 'controller':
        subprocess.call(shlex.split("""wall -n '
/home on the controller was mounted over the existing /home.
Either log out and log back in or cd into ~.
'"""))
# END start_motd()


def install_packages():

    if cfg.instance_type == 'compute':
        hostname = socket.gethostname()
        pid = util.get_pid(hostname)
        if (cfg.partitions[pid]['gpu_count'] or
                (f"{cfg.compute_node_prefix}-image" in hostname and
                 next((part for part in cfg.partitions if part['gpu_count']),
                      None))):
            subprocess.call("yum -y install kernel-devel-$(uname -r) kernel-headers-$(uname -r)", shell=True)
            subprocess.call(shlex.split(
                "wget http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/" + rpm))
            subprocess.call(shlex.split("rpm -i " + rpm))
            subprocess.call(shlex.split("yum clean all"))
            subprocess.call(shlex.split("yum -y install cuda"))
            # Creates the device files
            subprocess.call(shlex.split("nvidia-smi"))
# END install_packages()


def setup_munge():

    munge_service_patch = Path('/usr/lib/systemd/system/munge.service')
    with munge_service_patch.open('w') as f:
        f.write("""
[Unit]
Description=MUNGE authentication service
Documentation=man:munged(8)
After=network.target
After=syslog.target
After=time-sync.target{}

[Service]
Type=forking
ExecStart=/usr/sbin/munged --num-threads=10
PIDFile=/var/run/munge/munged.pid
User=munge
Group=munge
Restart=on-abort

[Install]
WantedBy=multi-user.target
""".format(f"\nRequiresMountsFor={MUNGE_DIR}"
           if cfg.instance_type != 'controller' else ''))

    subprocess.call(shlex.split("systemctl enable munge"))

    if (cfg.instance_type != 'controller'):
        with open('/etc/fstab', 'a') as f:
            f.write("\n{1}:{0} \t{0} \tnfs \trw,hard,intr \t0 \t0"
                    .format(MUNGE_DIR, CONTROL_MACHINE))
        return

    if cfg.munge_key:
        with (MUNGE_DIR/'munge.key').open('w') as f:
            f.write(cfg.munge_key)

        subprocess.call(shlex.split(
            f"chown -R munge: {MUNGE_DIR} /var/log/munge/"))

        (MUNGE_DIR/'munge_key').chmod(0o400)
        MUNGE_DIR.chmod(0o700)
        Path('var/log/munge/').chmod(0o700)
    else:
        subprocess.call('create-munge-key')
# END setup_munge ()


def start_munge():
    subprocess.call(shlex.split("systemctl start munge"))
# END start_munge()


def setup_nfs_exports():

    with open('/etc/exports', 'w') as f:
        if not cfg.nfs_home_server:
            f.write("\n/home  *(rw,no_subtree_check,no_root_squash)")
        if not cfg.nfs_apps_server:
            f.write(f"\n{APPS_DIR}  *(rw,no_subtree_check,no_root_squash)")
        f.write("\n/etc/munge *(rw,no_subtree_check,no_root_squash)")
        if cfg.controller_secondary_disk:
            f.write("\n{} *(rw,no_subtree_check,no_root_squash)"
                    .format(SEC_DISK_DIR))

    subprocess.call(shlex.split("exportfs -a"))
# END setup_nfs_exports()


def expand_machine_type():

    # Assume sockets is 1. Currently, no instances with multiple sockets
    # Assume hyper-threading is on and 2 threads per core
    machines = []
    compute = googleapiclient.discovery.build('compute', 'v1',
                                              cache_discovery=False)
    for part in cfg.partitions:
        machine = {'sockets': 1, 'cores': 1, 'threads': 1, 'memory': 1}
        try:
            type_resp = compute.machineTypes().get(
                project=cfg.project, zone=part['zone'],
                machineType=part['machine_type']).execute()
            if type_resp:
                tot_cpus = type_resp['guestCpus']
                if tot_cpus > 1:
                    machine['cores'] = tot_cpus // 2
                    machine['threads'] = 2

                # Because the actual memory on the host will be different than
                # what is configured (e.g. kernel will take it). From
                # experiments, about 16 MB per GB are used (plus about 400 MB
                # buffer for the first couple of GB's. Using 30 MB to be safe.
                gb = type_resp['memoryMb'] // 1024
                machine['memory'] = type_resp['memoryMb'] - (400 + (gb * 30))

        except Exception as e:
            print("Failed to get MachineType '{}' from google api ({})"
                  .format(part["machine_type"], str(e)))
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

    conf = f"""
# slurm.conf file generated by configurator.html.
# Put this file on all nodes of your cluster.
# See the slurm.conf man page for more information.
#
ControlMachine={CONTROL_MACHINE}
#ControlAddr=
#BackupController=
#BackupAddr=
#
AuthType=auth/munge
AuthInfo=cred_expire=120
#CheckpointType=checkpoint/none
CryptoType=crypto/munge
#DisableRootJobs=NO
#EnforcePartLimits=NO
#Epilog=
#EpilogSlurmctld=
#FirstJobId=1
#MaxJobId=999999
#GroupUpdateForce=0
#GroupUpdateTime=600
#JobCheckpointDir=/var/slurm/checkpoint
#JobCredentialPrivateKey=
#JobCredentialPublicCertificate=
#JobFileAppend=0
#JobRequeue=1
#JobSubmitPlugins=1
#KillOnBadExit=0
#LaunchType=launch/slurm
#Licenses=foo*4,bar
#MailProg=/bin/mail
#MaxJobCount=5000
#MaxStepCount=40000
#MaxTasksPerNode=128
MpiDefault={mpi_default}
#MpiParams=ports=#-#
#PluginDir=
#PlugStackConfig=
#PrivateData=jobs
LaunchParameters=send_gids,enable_nss_slurm

# Always show cloud nodes. Otherwise cloud nodes are hidden until they are
# resumed. Having them shown can be useful in detecting downed nodes.
# NOTE: slurm won't allocate/resume nodes that are down. So in the case of
# preemptible nodes -- if gcp preempts a node, the node will eventually be put
# into a down date because the node will stop responding to the controller.
# (e.g. SlurmdTimeout).
PrivateData=cloud

ProctrackType=proctrack/cgroup

#Prolog=
#PrologFlags=
#PrologSlurmctld=
#PropagatePrioProcess=0
#PropagateResourceLimits=
#PropagateResourceLimitsExcept=Sched
#RebootProgram=

ReturnToService=2
#SallocDefaultCommand=
SlurmctldPidFile=/var/run/slurm/slurmctld.pid
SlurmctldPort=6820-6830
SlurmdPidFile=/var/run/slurm/slurmd.pid
SlurmdPort=6818
SlurmdSpoolDir=/var/spool/slurmd
SlurmUser=slurm
#SlurmdUser=root
#SrunEpilog=
#SrunProlog=
StateSaveLocation={APPS_DIR}/slurm/state
SwitchType=switch/none
#TaskEpilog=
TaskPlugin=task/affinity,task/cgroup
#TaskPluginParam=
#TaskProlog=
#TopologyPlugin=topology/tree
#TmpFS=/tmp
#TrackWCKey=no
#TreeWidth=
#UnkillableStepProgram=
#UsePAM=0
#
#
# TIMERS
#BatchStartTimeout=10
#CompleteWait=0
#EpilogMsgTime=2000
#GetEnvTimeout=2
#HealthCheckInterval=0
#HealthCheckProgram=
InactiveLimit=0
KillWait=30
MessageTimeout=60
#ResvOverRun=0
MinJobAge=300
#OverTimeLimit=0
SlurmctldTimeout=120
SlurmdTimeout=300
#UnkillableStepTimeout=60
#VSizeFactor=0
Waittime=0
#
#
# SCHEDULING
FastSchedule=1
#MaxMemPerCPU=0
#SchedulerTimeSlice=30
SchedulerType=sched/backfill
SelectType=select/cons_res
SelectTypeParameters=CR_Core_Memory
#
#
# JOB PRIORITY
#PriorityFlags=
#PriorityType=priority/basic
#PriorityDecayHalfLife=
#PriorityCalcPeriod=
#PriorityFavorSmall=
#PriorityMaxAge=
#PriorityUsageResetPeriod=
#PriorityWeightAge=
#PriorityWeightFairshare=
#PriorityWeightJobSize=
#PriorityWeightPartition=
#PriorityWeightQOS=
#
#
# LOGGING AND ACCOUNTING
#AccountingStorageEnforce=associations,limits,qos,safe
AccountingStorageHost={CONTROL_MACHINE}
#AccountingStorageLoc=
#AccountingStoragePass=
#AccountingStoragePort=
AccountingStorageType=accounting_storage/slurmdbd
#AccountingStorageUser=
AccountingStoreJobComment=YES
ClusterName={cfg.cluster_name}
#DebugFlags=powersave
#JobCompHost=
#JobCompLoc=
#JobCompPass=
#JobCompPort=
JobCompType=jobcomp/none
#JobCompUser=
#JobContainerType=job_container/none
JobAcctGatherFrequency=30
JobAcctGatherType=jobacct_gather/linux
SlurmctldDebug=info
SlurmctldLogFile={SLURM_LOG}/slurmctld.log
SlurmdDebug=debug
SlurmdLogFile={SLURM_LOG}/slurmd-%n.log
#
#
# POWER SAVE SUPPORT FOR IDLE NODES (optional)
SuspendProgram={APPS_DIR}/slurm/scripts/suspend.py
ResumeProgram={APPS_DIR}/slurm/scripts/resume.py
ResumeFailProgram={APPS_DIR}/slurm/scripts/suspend.py
SuspendTimeout={SUSPEND_TIMEOUT}
ResumeTimeout={RESUME_TIMEOUT}
ResumeRate=0
#SuspendExcNodes=
#SuspendExcParts=
SuspendRate=0
SuspendTime={cfg.suspend_time}
#
SchedulerParameters=salloc_wait_nodes
SlurmctldParameters=cloud_dns,idle_on_node_suspend
CommunicationParameters=NoAddrCache
GresTypes=gpu
#
# COMPUTE NODES
"""

    static_nodes = []
    for i, machine in enumerate(machines):
        part = cfg.partitions[i]
        static_range = ''
        if part['static_node_count']:
            if part['static_node_count'] > 1:
                static_range = '{}-{}-[0-{}]'.format(
                    cfg.compute_node_prefix, i, part['static_node_count'] - 1)
            else:
                static_range = f"{cfg.compute_node_prefix}-{i}-0"

        cloud_range = ""
        if (part['max_node_count'] and
                (part['max_node_count'] != part['static_node_count'])):
            cloud_range = "{}-{}-[{}-{}]".format(
                cfg.compute_node_prefix, i, part['static_node_count'],
                part['max_node_count'] - 1)

        conf += ' '.join(("NodeName=DEFAULT",
                          "Sockets="        + str(machine['sockets']),
                          "CoresPerSocket=" + str(machine['cores']),
                          "ThreadsPerCore=" + str(machine['threads']),
                          "RealMemory="     + str(machine['memory']),
                          "State=UNKNOWN"))

        if part['gpu_count']:
            conf += " Gres=gpu:" + str(part['gpu_count'])
        conf += '\n'

        # Nodes
        if static_range:
            static_nodes.append(static_range)
            conf += "NodeName={}\n".format(static_range)

        if cloud_range:
            conf += "NodeName={} State=CLOUD\n".format(cloud_range)

        # Partitions
        part_nodes = f"-{i}-[0-{part['max_node_count'] - 1}]"

        total_threads = machine['threads']*machine['cores']*machine['sockets']
        def_mem_per_cpu = max(100, machine['memory'] // total_threads)

        conf += ("PartitionName={} Nodes={}-compute{} MaxTime=INFINITE "
                 "State=UP DefMemPerCPU={} LLN=yes"
                 .format(part['name'], cfg.cluster_name, part_nodes,
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

    conf = f"""
#ArchiveEvents=yes
#ArchiveJobs=yes
#ArchiveResvs=yes
#ArchiveSteps=no
#ArchiveSuspend=no
#ArchiveTXN=no
#ArchiveUsage=no

AuthType=auth/munge
DbdHost={CONTROL_MACHINE}
DebugLevel=debug2

#PurgeEventAfter=1month
#PurgeJobAfter=12month
#PurgeResvAfter=1month
#PurgeStepAfter=1month
#PurgeSuspendAfter=1month
#PurgeTXNAfter=12month
#PurgeUsageAfter=24month

LogFile={SLURM_LOG}/slurmdbd.log
PidFile=/var/run/slurm/slurmdbd.pid

SlurmUser=slurm
StorageUser=slurm

StorageLoc=slurm_acct_db

StorageType=accounting_storage/mysql
#StorageUser=database_mgr
#StoragePass=shazaam

"""
    etc_dir = CURR_SLURM_DIR/'etc'
    if not etc_dir.exists():
        etc_dir.mkdir(parents=True)
    with (etc_dir/'slurmdbd.conf').open('w') as f:
        f.write(conf)

# END install_slurmdbd_conf()


def install_cgroup_conf():

    conf = """
CgroupAutomount=no
#CgroupMountpoint=/sys/fs/cgroup
ConstrainCores=yes
ConstrainRamSpace=yes
ConstrainSwapSpace=yes
TaskAffinity=no
ConstrainDevices=yes
"""

    etc_dir = CURR_SLURM_DIR/'etc'
    with (etc_dir/'cgroup.conf').open('w') as f:
        f.write(conf)

    with (etc_dir/'cgroup_allowed_devices_file.conf').open('w') as f:
        f.write('')

    gpu_parts = [(i, x) for i, x in enumerate(cfg.partitions)
                 if x['gpu_count']]
    gpu_conf = ""
    for i, part in gpu_parts:
        driver_range = '0'
        if part['gpu_count'] > 1:
            driver_range = '[0-{}]'.format(part['gpu_count']-1)

        gpu_conf += ("NodeName={}-{}-[0-{}] Name=gpu File=/dev/nvidia{}\n"
                     .format(cfg.compute_node_prefix, i,
                             part['max_node_count'] - 1, driver_range))
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

    subprocess.call(shlex.split(
        "gcloud compute instances remove-metadata {} --zone={} --keys={}"
        .format(CONTROL_MACHINE, cfg.zone,
                ','.join([x[1] for x in meta_files]))))

# END install_meta_files()


@contextmanager
def cd(path):
    """ Change working directory for context """
    prev = Path.cwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(prev)


def install_slurm():

    src_path = APPS_DIR/'slurm/src'
    if not src_path.exists():
        src_path.mkdir(parents=True)

    with cd(src_path):
        use_version = ''
        if (cfg.slurm_version[0:2] == 'b:'):
            GIT_URL = 'https://github.com/SchedMD/slurm.git'
            use_version = cfg.slurm_version[2:]
            subprocess.call(shlex.split(
                "git clone -b {0} {1} {0}".format(use_version, GIT_URL)))
        else:
            file = 'slurm-{}.tar.bz2'.format(cfg.slurm_version)
            slurm_url = 'https://download.schedmd.com/slurm/' + file
            urllib.request.urlretrieve(slurm_url, src_path/file)

            use_version = subprocess.check_output(shlex.split(
                "tar -xvjf " + file)).decode().splitlines()[0][:-1]

    SLURM_PREFIX = APPS_DIR/'slurm'/use_version

    build_dir = src_path/use_version/'build'
    if not build_dir.exists():
        build_dir.mkdir(parents=True)

    with cd(build_dir):
        subprocess.call(shlex.split(
            "../configure --prefix={} --sysconfdir={}/etc"
            .format(SLURM_PREFIX, CURR_SLURM_DIR)), stdout=subprocess.DEVNULL)
        subprocess.call(shlex.split("make -j install"),
                        stdout=subprocess.DEVNULL)
    with cd(build_dir/'contribs'):
        subprocess.call(shlex.split("make -j install"),
                        stdout=subprocess.DEVNULL)

    os.symlink(SLURM_PREFIX, CURR_SLURM_DIR)

    state_dir = APPS_DIR/'slurm/state'
    if not state_dir.exists():
        state_dir.mkdir(parents=True)
        subprocess.call(shlex.split("chown -R slurm: {}".format(state_dir)))

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

    subprocess.call(shlex.split(f"chown slurm: {run_dir}"))

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
After=network.target munge.service
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
    subprocess.call(shlex.split('systemctl enable slurmd'))

# END install_compute_service_scripts()


def setup_bash_profile():

    with open('/etc/profile.d/slurm.sh', 'w') as f:
        f.write("""
S_PATH={}
PATH=$PATH:$S_PATH/bin:$S_PATH/sbin
""".format(CURR_SLURM_DIR))

    if cfg.instance_type == 'compute':
        pid = util.get_pid(socket.gethostname())
        if cfg.partitions[pid]['gpu_count']:
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
#END setup_ompi_bash_profile()


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


def setup_nfs_apps_vols():

    with open('/etc/fstab', 'a') as f:
        if not cfg.nfs_apps_server:
            if cfg.instance_type != 'controller':
                f.write("\n{1}:{0} \t{0} \tnfs \trw,hard,intr \t0 \t0"
                        .format(APPS_DIR, CONTROL_MACHINE))
        else:
            f.write("\n{1}:{2} \t{0} \tnfs \trw,hard,intr \t0 \t0\n"
                    .format(APPS_DIR, cfg.nfs_apps_server,
                            cfg.nfs_apps_dir))

# END setup_nfs_apps_vols()


def setup_nfs_home_vols():

    with open('/etc/fstab', 'a') as f:
        if not cfg.nfs_home_server:
            if ((cfg.instance_type != 'controller')):
                f.write("\n{0}:/home \t/home \tnfs \trw,hard,intr \t0 \t0"
                        .format(CONTROL_MACHINE))
        else:
            f.write("\t{0}:{1} \t/home \tnfs \trw,hard,intr \t0 \t0"
                    .format(cfg.nfs_home_server, cfg.nfs_home_dir))

# END setup_nfs_home_vols()


def setup_nfs_sec_vols():
    if (cfg.controller_secondary_disk and
            (cfg.instance_type != 'controller')):
        with open('/etc/fstab', 'a') as f:
            f.write("\n{1}:{0} \t{0} \tnfs \trw,hard,intr \t0 \t0"
                    .format(SEC_DISK_DIR, CONTROL_MACHINE))

# END setup_nfs_sec_vols()


def setup_secondary_disks():

    subprocess.call(shlex.split(
        "sudo mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb"))
    with open('/etc/fstab', 'a') as f:
        f.write("\n/dev/sdb \t{0} \text4 \tdiscard,defaults,nofail \t0 \t2"
                .format(SEC_DISK_DIR))

# END setup_secondary_disks()


def mount_nfs_vols():
    while subprocess.call(shlex.split("mount -a")):
        print("Waiting for " + str(APPS_DIR) + " and /home to be mounted")
        time.sleep(5)

# END mount_nfs_vols()


# Tune the NFS server to support many mounts
def setup_nfs_threads():

    with open('/etc/sysconfig/nfs', 'a') as f:
        f.write("""
# Added by Google
RPCNFSDCOUNT=256
""".format(APPS_DIR))

# END setup_nfs_threads()


def setup_sync_cronjob():

    os.system(("echo '*/1 * * * * {}/slurm/scripts/slurmsync.py' "
              "| crontab -u root -").format(APPS_DIR))

# END setup_sync_cronjob()


def setup_slurmd_cronjob():
    # subprocess.call(shlex.split('crontab < /apps/slurm/scripts/cron'))
    os.system("echo '*/2 * * * * if [ `systemctl status slurmd "
              "| grep -c inactive` -gt 0 ]; then mount -a; "
              "systemctl restart slurmd; fi' | crontab -u root -")
# END setup_slurmd_cronjob()


def create_compute_image():

    end_motd(False)
    subprocess.call('sync')
    ver = datetime.datetime.now().strftime('%Y-%m-%d-%H-%M-%S')

    hostname = socket.gethostname()
    if next((part for part in cfg.partitions if part['gpu_count']), None):
        time.sleep(300)

    print("Creating compute image...")
    subprocess.call(shlex.split(
        f"gcloud compute images create {cfg.compute_node_prefix}-image-{ver} "
        f"--source-disk {hostname} --source-disk-zone {cfg.zone} --force "
        f"--family {cfg.compute_node_prefix}-image-family"))
# END create_compute_image()


def setup_selinux():

    subprocess.call(shlex.split('setenforce 0'))
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
    subprocess.call(['yum', 'install', '-y'] + packages)

    ompi_git = "https://github.com/open-mpi/ompi.git"
    ompi_path = APPS_DIR/'ompi'/cfg.ompi_version/'src'
    if not ompi_path.exists():
        ompi_path.mkdir(parents=True)
    subprocess.call(shlex.split(
        f"git clone -b {cfg.ompi_version} {ompi_git} {ompi_path}"))
    with cd(ompi_path):
        subprocess.call("./autogen.pl", stdout=subprocess.DEVNULL)

    build_path = ompi_path/'build'
    if not build_path.exists():
        build_path.mkdir(parents=True)
    with cd(build_path):
        subprocess.call(shlex.split(
            f"../configure --prefix={APPS_DIR}/ompi/{cfg.ompi_version} "
            f"--with-pmi={APPS_DIR}/slurm/current --with-libevent=/usr "
            "--with-hwloc=/usr"),
                        stdout=subprocess.DEVNULL)
        subprocess.call(shlex.split("make -j install"),
                        stdout=subprocess.DEVNULL)
#END install_ompi()

def remove_startup_scripts(hostname):

    cmd = "gcloud compute instances remove-metadata"
    keys = "startup-script,setup_script,util_script,config"
    if f"{cfg.compute_node_prefix}-image" in hostname:
        subprocess.call(shlex.split(
            f"{cmd} {hostname} --zone={cfg.zone} --keys={keys}"))

    elif cfg.instance_type == 'controller':
        # controller
        subprocess.call(shlex.split(
            f"{cmd} {hostname} --zone={cfg.zone} --keys={keys}"))

        # logins
        for i in range(1, cfg.login_node_count + 1):
            subprocess.call(shlex.split(
                "{} {}-login{} --zone={} --keys={}"
                .format(cmd, cfg.cluster_name, i, cfg.zone, keys)))

        # computes
        for i, part in enumerate(cfg.partitions):
            if not part['static_node_count']:
                continue
            for j in range(part['static_node_count']):
                subprocess.call(shlex.split(
                    "{} {}-{}-{} --zone={} --keys={}"
                    .format(cmd, cfg.compute_node_prefix, i, j, part['zone'],
                            keys)))
# END remove_startup_scripts()


def setup_nss_slurm():

    # setup nss_slurm
    subprocess.call(shlex.split(
        "ln -s {}/lib/libnss_slurm.so.2 /usr/lib64/libnss_slurm.so.2"
        .format(CURR_SLURM_DIR)))
    subprocess.call(shlex.split(
        "sed -i 's/\\(^\\(passwd\\|group\\):\\s\\+\\)/\\1slurm /g' /etc/nsswitch.conf"))
# END setup_nss_slurm()


def main():
    hostname = socket.gethostname()

    setup_selinux()

    if not (APPS_DIR/'slurm').exists():
        (APPS_DIR/'slurm').mkdir(parents=True)
        print("ww Created Slurm Folders")

    if cfg.controller_secondary_disk:
        if not SEC_DISK_DIR.exists():
            SEC_DISK_DIR.mkdir(parents=True)

    start_motd()

    add_slurm_user()
    install_packages()
    setup_munge()
    setup_bash_profile()
    setup_ompi_bash_profile()
    setup_modules()

    if (cfg.controller_secondary_disk and
            (cfg.instance_type == 'controller')):
        setup_secondary_disks()

    setup_nfs_apps_vols()
    setup_nfs_home_vols()
    setup_nfs_sec_vols()

    if not SLURM_LOG.exists():
        SLURM_LOG.mkdir(parents=True)
    shutil.chown(SLURM_LOG, user='slurm', group='slurm')

    if cfg.instance_type == 'controller':
        mount_nfs_vols()
        start_munge()
        install_slurm()
        install_ompi()

        try:
            subprocess.call('{}/slurm/scripts/custom-controller-install'
                            .format(APPS_DIR))
        except Exception:
            # Ignore blank files with no shell magic.
            pass

        install_controller_service_scripts()

        subprocess.call(shlex.split('systemctl enable mariadb'))
        subprocess.call(shlex.split('systemctl start mariadb'))

        subprocess.call(shlex.split(
            """mysql -u root -e "create user 'slurm'@'localhost'";"""))
        subprocess.call(shlex.split(
            """mysql -u root -e "grant all on slurm_acct_db.* TO 'slurm'@'localhost'";"""))
        subprocess.call(shlex.split(
            """mysql -u root -e "grant all on slurm_acct_db.* TO 'slurm'@'{0}'";"""
            .format(CONTROL_MACHINE)))

        subprocess.call(shlex.split("systemctl enable slurmdbd"))
        subprocess.call(shlex.split("systemctl start slurmdbd"))

        # Wait for slurmdbd to come up
        time.sleep(5)

        sacctmgr = f"{CURR_SLURM_DIR}/bin/sacctmgr -i"
        subprocess.call(
            shlex.split(sacctmgr + " add cluster " + cfg.cluster_name))

        subprocess.call(shlex.split("systemctl enable slurmctld"))
        subprocess.call(shlex.split("systemctl start slurmctld"))
        setup_nfs_threads()
        # Export at the end to signal that everything is up
        subprocess.call(shlex.split("systemctl enable nfs-server"))
        subprocess.call(shlex.split("systemctl start nfs-server"))
        setup_nfs_exports()

        setup_sync_cronjob()

        # DOWN partitions until image is created.
        for part in cfg.partitions:
            subprocess.call(shlex.split(
                "{}/bin/scontrol update partitionname={} state=down".format(
                    CURR_SLURM_DIR, part['name'])))

        print("ww Done installing controller")
    elif cfg.instance_type == 'compute':
        install_compute_service_scripts()
        setup_slurmd_cronjob()
        mount_nfs_vols()
        start_munge()
        setup_nss_slurm()

        try:
            subprocess.call(APPS_DIR/'slurm/scripts/custom-compute-install')
        except Exception:
            # Ignore blank files with no shell magic.
            pass

        if f"{cfg.compute_node_prefix}-image" in hostname:

            create_compute_image()

            for part in cfg.partitions:
                subprocess.call(shlex.split(
                    "{}/bin/scontrol update partitionname={} state=up".format(
                        CURR_SLURM_DIR, part['name'])))

            remove_startup_scripts(hostname)

            subprocess.call(shlex.split(
                f"gcloud compute instances stop {hostname} "
                f"--zone {cfg.zone} --quiet"))
        else:
            subprocess.call(shlex.split("systemctl start slurmd"))

    else:  # login nodes
        mount_nfs_vols()
        start_munge()

        try:
            subprocess.call("{}/slurm/scripts/custom-compute-install"
                            .format(APPS_DIR))
        except Exception:
            # Ignore blank files with no shell magic.
            pass

    remove_startup_scripts(hostname)
    setup_logrotate()

    end_motd()

# END main()


if __name__ == '__main__':
    main()
