#!/usr/bin/env python2

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
import httplib
import os
import shlex
import socket
import subprocess
import time
import urllib
import urllib2

CLUSTER_NAME      = '@CLUSTER_NAME@'
INSTANCE_TYPE     = '@INSTANCE_TYPE@'  # e.g. controller, login, compute

PROJECT           = '@PROJECT@'
ZONE              = '@ZONE@'

APPS_DIR          = '/apps'
CURR_SLURM_DIR    = APPS_DIR + '/slurm/current'
MUNGE_DIR         = "/etc/munge"
MUNGE_KEY         = '@MUNGE_KEY@'
SLURM_VERSION     = '@SLURM_VERSION@'
DEF_SLURM_ACCT    = '@DEF_SLURM_ACCT@'
DEF_SLURM_USERS   = '@DEF_SLURM_USERS@'
EXTERNAL_COMPUTE_IPS = @EXTERNAL_COMPUTE_IPS@
NFS_APPS_SERVER   = '@NFS_APPS_SERVER@'
NFS_APPS_DIR      = '@NFS_APPS_DIR@'
NFS_HOME_SERVER   = '@NFS_HOME_SERVER@'
NFS_HOME_DIR      = '@NFS_HOME_DIR@'
CONTROLLER_SECONDARY_DISK = @CONTROLLER_SECONDARY_DISK@
SEC_DISK_DIR      = '/mnt/disks/sec'
SUSPEND_TIME      = @SUSPEND_TIME@
RESUME_TIMEOUT    = 300
SUSPEND_TIMEOUT   = 300
PARTITIONS        = @PARTITIONS@
LOGIN_NODE_COUNT  = @LOGIN_NODE_COUNT@

CONTROL_MACHINE = CLUSTER_NAME + '-controller'
MAX_PARTITION_SIZE = 10000

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

    appsmfs = '/apps/modulefiles'

    with open('/usr/share/Modules/init/.modulespath', 'r+') as dotmp:
        if appsmfs not in dotmp.read():
            if INSTANCE_TYPE != 'controller' and not os.path.isdir(appsmfs):
                os.makedirs(appsmfs)
            # after read, file cursor is at end of file
            dotmp.write('\n' + appsmfs + '\n')
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

    if INSTANCE_TYPE != "controller":
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
        .format(INSTANCE_TYPE)))

    if INSTANCE_TYPE != 'controller':
        subprocess.call(shlex.split("""wall -n '
/home on the controller was mounted over the existing /home.
Either log out and log back in or cd into ~.
'"""))
# END start_motd()


def have_internet():
    conn = httplib.HTTPConnection("www.google.com", timeout=1)
    try:
        conn.request("HEAD", "/")
        conn.close()
        return True
    except:
        conn.close()
        return False
# END have_internet()


def install_packages():

    packages = ['bind-utils',
                'epel-release',
                'gcc',
                'git',
                'hwloc',
                'hwloc-devel',
                'libibmad',
                'libibumad',
                'lua',
                'lua-devel',
                'man2html',
                'mariadb',
                'mariadb-devel',
                'mariadb-server',
                'munge',
                'munge-devel',
                'munge-libs',
                'ncurses-devel',
                'nfs-utils',
                'numactl',
                'numactl-devel',
                'openssl-devel',
                'pam-devel',
                'perl-ExtUtils-MakeMaker',
                'python-pip',
                'readline-devel',
                'rpm-build',
                'rrdtool-devel',
                'vim',
                'wget',
                'tmux',
                'pdsh',
                'openmpi'
                ]

    while subprocess.call(shlex.split("yum install -y") + packages):
        print("yum failed to install packages. Trying again in 5 seconds")
        time.sleep(5)

    while subprocess.call(shlex.split(
            "pip install --upgrade google-api-python-client")):
        print("failed to install google python api client. Trying again 5 seconds.")
        time.sleep(5)

    if INSTANCE_TYPE == 'compute':
        hostname = socket.gethostname()
        pid = int(hostname[-6:-4])
        if PARTITIONS[pid]['gpu_count']:
            rpm = 'cuda-repo-rhel7-10.0.130-1.x86_64.rpm'
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

    munge_service_patch = '/usr/lib/systemd/system/munge.service'
    with open(munge_service_patch, 'w') as f:
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
""".format("\nRequiresMountsFor=" + MUNGE_DIR
           if INSTANCE_TYPE != 'controller' else ''))

    subprocess.call(shlex.split("systemctl enable munge"))

    if (INSTANCE_TYPE != 'controller'):
        with open('/etc/fstab', 'a') as f:
            f.write("\n{1}:{0} \t{0} \tnfs \trw,hard,intr \t0 \t0"
                    .format(MUNGE_DIR, CONTROL_MACHINE))
        return

    if MUNGE_KEY:
        with open(MUNGE_DIR + '/munge.key', 'w') as f:
            f.write(MUNGE_KEY)

        subprocess.call(shlex.split("chown -R munge: {} /var/log/munge/"
                                    .format(MUNGE_DIR)))
        os.chmod(MUNGE_DIR + '/munge.key', 0o400)
        os.chmod(MUNGE_DIR, 0o700)
        os.chmod('/var/log/munge/', 0o700)
    else:
        subprocess.call('create-munge-key')
# END setup_munge ()


def start_munge():
    subprocess.call(shlex.split("systemctl start munge"))
# END start_munge()


def setup_nfs_exports():

    with open('/etc/exports', 'w') as f:
        if not NFS_HOME_SERVER:
            f.write("\n/home  *(rw,no_subtree_check,no_root_squash)")
        if not NFS_APPS_SERVER:
            f.write("\n{}  *(rw,no_subtree_check,no_root_squash)"
                    .format(APPS_DIR))
        f.write("\n/etc/munge *(rw,no_subtree_check,no_root_squash)")
        if CONTROLLER_SECONDARY_DISK:
            f.write("\n{} *(rw,no_subtree_check,no_root_squash)"
                    .format(SEC_DISK_DIR))

    subprocess.call(shlex.split("exportfs -a"))
# END setup_nfs_exports()


def expand_machine_type():

    # Force re-evaluation of site-packages so that namespace packages (such
    # as google-auth) are importable. This is needed because we install the
    # packages while this script is running and do not have the benefit of
    # restarting the interpreter for it to do it's usual startup sequence to
    # configure import magic.
    import sys
    import site
    for path in [x for x in sys.path if 'site-packages' in x]:
        site.addsitedir(path)

    import googleapiclient.discovery

    # Assume sockets is 1. Currently, no instances with multiple sockets
    # Assume hyper-threading is on and 2 threads per core
    machines = []
    for part in PARTITIONS:
        machine = {'sockets': 1, 'cores': 1, 'threads': 1, 'memory': 1}
        try:
            compute = googleapiclient.discovery.build('compute', 'v1',
                                                      cache_discovery=False)
            type_resp = compute.machineTypes().get(
                project=PROJECT, zone=part['zone'],
                machineType=part['machine_type']).execute()
            if type_resp:
                tot_cpus = type_resp['guestCpus']
                if tot_cpus > 1:
                    machine['cores'] = tot_cpus / 2
                    machine['threads'] = 2

                # Because the actual memory on the host will be different than
                # what is configured (e.g. kernel will take it). From
                # experiments, about 16 MB per GB are used (plus about 400 MB
                # buffer for the first couple of GB's. Using 30 MB to be safe.
                gb = type_resp['memoryMb'] / 1024
                machine['memory'] = type_resp['memoryMb'] - (400 + (gb * 30))

        except Exception, e:
            print("Failed to get MachineType '{}' from google api ({})"
                  .format(part["machine_type"], str(e)))
        finally:
            machines.append(machine)

    return machines
# END expand_machine_type()


def install_slurm_conf():

    machines = expand_machine_type()

    conf = """
# slurm.conf file generated by configurator.html.
# Put this file on all nodes of your cluster.
# See the slurm.conf man page for more information.
#
ControlMachine={control_machine}
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
MpiDefault=none
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
StateSaveLocation={apps_dir}/slurm/state
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
AccountingStorageEnforce=associations,limits,qos,safe
AccountingStorageHost={control_machine}
#AccountingStorageLoc=
#AccountingStoragePass=
#AccountingStoragePort=
AccountingStorageType=accounting_storage/slurmdbd
#AccountingStorageUser=
AccountingStoreJobComment=YES
ClusterName={cluster_name}
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
SlurmctldLogFile={apps_dir}/slurm/log/slurmctld.log
SlurmdDebug=debug
SlurmdLogFile=/var/log/slurm/slurmd-%n.log
#
#
# POWER SAVE SUPPORT FOR IDLE NODES (optional)
SuspendProgram={apps_dir}/slurm/scripts/suspend.py
ResumeProgram={apps_dir}/slurm/scripts/resume.py
ResumeFailProgram={apps_dir}/slurm/scripts/suspend.py
SuspendTimeout={suspend_timeout}
ResumeTimeout={resume_timeout}
ResumeRate=0
#SuspendExcNodes=
#SuspendExcParts=
SuspendRate=0
SuspendTime={suspend_time}
#
SchedulerParameters=salloc_wait_nodes
SlurmctldParameters=cloud_dns,idle_on_node_suspend
CommunicationParameters=NoAddrCache
GresTypes=gpu
#
# COMPUTE NODES
""".format(apps_dir=APPS_DIR,
           cluster_name=CLUSTER_NAME,
           control_machine=CONTROL_MACHINE,
           suspend_timeout=SUSPEND_TIMEOUT,
           resume_timeout=RESUME_TIMEOUT,
           suspend_time=SUSPEND_TIME)

    static_nodes = []
    for i, machine in enumerate(machines):
        part = PARTITIONS[i]
        static_range = ''
        if part['static_node_count']:
            if part['static_node_count'] > 1:
                static_range = '{}-compute[{:06}-{:06}]'.format(
                    CLUSTER_NAME,
                    i*MAX_PARTITION_SIZE,
                    i*MAX_PARTITION_SIZE + part['static_node_count'] - 1)
            else:
                static_range = '{}-compute{:06}'.format(CLUSTER_NAME,
                                                        i*MAX_PARTITION_SIZE)

        cloud_range = ""
        if (part['max_node_count'] and
                (part['max_node_count'] != part['static_node_count'])):
            cloud_range = "{}-compute[{:06d}-{:06d}]".format(
                CLUSTER_NAME,
                i*MAX_PARTITION_SIZE+part['static_node_count'],
                i*MAX_PARTITION_SIZE+part['max_node_count']-1)

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
        part_nodes = "[{:06}-{:06}]".format(
            i*MAX_PARTITION_SIZE,
            i*MAX_PARTITION_SIZE+part['max_node_count']-1)

        total_threads = machine['threads']*machine['cores']*machine['sockets']
        def_mem_per_cpu = max(100, machine['memory'] / total_threads)

        conf += ("PartitionName={} Nodes={}-compute{} MaxTime=INFINITE "
                 "State=UP DefMemPerCPU={} LLN=yes"
                 .format(part['name'], CLUSTER_NAME, part_nodes,
                         def_mem_per_cpu))

        # First partition specified is treated as the default partition
        if i == 0:
            conf += " Default=YES"
        conf += "\n\n"

    if len(static_nodes):
        conf += "\nSuspendExcNodes={}\n".format(','.join(static_nodes))

    etc_dir = CURR_SLURM_DIR + '/etc'
    if not os.path.exists(etc_dir):
        os.makedirs(etc_dir)
    with open(etc_dir + '/slurm.conf', 'w') as f:
        f.write(conf)
# END install_slurm_conf()


def install_slurmdbd_conf():

    conf = """
#ArchiveEvents=yes
#ArchiveJobs=yes
#ArchiveResvs=yes
#ArchiveSteps=no
#ArchiveSuspend=no
#ArchiveTXN=no
#ArchiveUsage=no

AuthType=auth/munge
DbdHost={control_machine}
DebugLevel=debug2

#PurgeEventAfter=1month
#PurgeJobAfter=12month
#PurgeResvAfter=1month
#PurgeStepAfter=1month
#PurgeSuspendAfter=1month
#PurgeTXNAfter=12month
#PurgeUsageAfter=24month

LogFile={apps_dir}/slurm/log/slurmdbd.log
PidFile=/var/run/slurm/slurmdbd.pid

SlurmUser=slurm
StorageUser=slurm

StorageLoc=slurm_acct_db

StorageType=accounting_storage/mysql
#StorageUser=database_mgr
#StoragePass=shazaam

""".format(apps_dir=APPS_DIR, control_machine=CONTROL_MACHINE)
    etc_dir = CURR_SLURM_DIR + '/etc'
    if not os.path.exists(etc_dir):
        os.makedirs(etc_dir)
    with open(etc_dir + '/slurmdbd.conf', 'w') as f:
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

    etc_dir = CURR_SLURM_DIR + '/etc'
    with open(etc_dir + '/cgroup.conf', 'w') as f:
        f.write(conf)

    with open(etc_dir + '/cgroup_allowed_devices_file.conf', 'w') as f:
        f.write('')

    gpu_parts = [(i, x) for i, x in enumerate(PARTITIONS) if x['gpu_count']]
    gpu_conf = ""
    for i, part in gpu_parts:
        driver_range = '0'
        if part['gpu_count'] > 1:
            driver_range = '[0-{}]'.format(part['gpu_count']-1)

        gpu_conf += ("NodeName={}-compute[{:06}-{:06}] Name=gpu File=/dev/nvidia{}\n"
                     .format(CLUSTER_NAME, i*MAX_PARTITION_SIZE,
                             i*MAX_PARTITION_SIZE+part['max_node_count']-1,
                             driver_range))
    if gpu_conf:
        with open(etc_dir + '/gres.conf', 'w') as f:
            f.write(gpu_conf)

# END install_cgroup_conf()


def install_meta_files():

    scripts_path = APPS_DIR + '/slurm/scripts'
    if not os.path.exists(scripts_path):
        os.makedirs(scripts_path)

    GOOGLE_URL = 'http://metadata.google.internal/computeMetadata/v1/instance/attributes'

    meta_files = [
        ('suspend.py', 'slurm_suspend'),
        ('resume.py', 'slurm_resume'),
        ('startup-script.py', 'startup-script-compute'),
        ('slurm-gcp-sync.py', 'slurm-gcp-sync'),
        ('compute-shutdown', 'compute-shutdown'),
        ('custom-compute-install', 'custom-compute-install'),
        ('custom-controller-install', 'custom-controller-install'),
    ]

    for file_name, meta_name in meta_files:
        req = urllib2.Request("{}/{}".format(GOOGLE_URL, meta_name))
        req.add_header('Metadata-Flavor', 'Google')
        resp = urllib2.urlopen(req)

        with open("{}/{}".format(scripts_path, file_name), 'w') as f:
            f.write(resp.read())
        os.chmod("{}/{}".format(scripts_path, file_name), 0o755)

        subprocess.call(shlex.split(
            "gcloud compute instances remove-metadata {} --zone={} --keys={}"
            .format(CONTROL_MACHINE, ZONE, meta_name)))

# END install_meta_files()


def install_slurm():

    SLURM_PREFIX = ''

    prev_path = os.getcwd()

    SRC_PATH = APPS_DIR + '/slurm/src'
    if not os.path.exists(SRC_PATH):
        os.makedirs(SRC_PATH)
    os.chdir(SRC_PATH)

    use_version = ''
    if (SLURM_VERSION[0:2] == 'b:'):
        GIT_URL = 'https://github.com/SchedMD/slurm.git'
        use_version = SLURM_VERSION[2:]
        subprocess.call(shlex.split(
            "git clone -b {0} {1} {0}".format(use_version, GIT_URL)))
    else:
        SCHEDMD_URL = 'https://download.schedmd.com/slurm/'
        file = 'slurm-{}.tar.bz2'.format(SLURM_VERSION)
        urllib.urlretrieve(SCHEDMD_URL + file, SRC_PATH + '/' + file)

        cmd = "tar -xvjf " + file
        use_version = subprocess.check_output(
            shlex.split(cmd)).splitlines()[0][:-1]

    os.chdir(use_version)
    SLURM_PREFIX = APPS_DIR + '/slurm/' + use_version

    if not os.path.exists('build'):
        os.makedirs('build')
    os.chdir('build')
    subprocess.call(shlex.split("../configure --prefix={} --sysconfdir={}/etc"
                    .format(SLURM_PREFIX, CURR_SLURM_DIR)))
    subprocess.call(shlex.split("make -j install"))
    os.chdir('contribs')
    subprocess.call(shlex.split("make -j install"))

    subprocess.call(shlex.split("ln -s {} {}".format(SLURM_PREFIX,
                                                     CURR_SLURM_DIR)))
    os.chdir(prev_path)

    state_dir = APPS_DIR + '/slurm/state'
    if not os.path.exists(state_dir):
        os.makedirs(state_dir)
        subprocess.call(shlex.split("chown -R slurm: {}".format(state_dir)))
    log_dir = APPS_DIR + '/slurm/log'
    if not os.path.exists(log_dir):
        os.makedirs(log_dir)
        subprocess.call(shlex.split("chown -R slurm: {}".format(log_dir)))

    install_slurm_conf()
    install_slurmdbd_conf()
    install_cgroup_conf()
    install_meta_files()

# END install_slurm()


def install_slurm_tmpfile():

    run_dir = '/var/run/slurm'

    with open('/etc/tmpfiles.d/slurm.conf', 'w') as f:
        f.write("\nd {} 0755 slurm slurm -".format(run_dir))

    if not os.path.exists(run_dir):
        os.makedirs(run_dir)

    os.chmod(run_dir, 0o755)
    subprocess.call(shlex.split("chown slurm: " + run_dir))

# END install_slurm_tmpfile()


def install_controller_service_scripts():

    install_slurm_tmpfile()

    # slurmctld.service
    with open('/usr/lib/systemd/system/slurmctld.service', 'w') as f:
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

    os.chmod('/usr/lib/systemd/system/slurmctld.service', 0o644)

    # slurmdbd.service
    with open('/usr/lib/systemd/system/slurmdbd.service', 'w') as f:
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

    os.chmod('/usr/lib/systemd/system/slurmdbd.service', 0o644)

# END install_controller_service_scripts()


def install_compute_service_scripts():

    install_slurm_tmpfile()

    # slurmd.service
    with open('/usr/lib/systemd/system/slurmd.service', 'w') as f:
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

    os.chmod('/usr/lib/systemd/system/slurmd.service', 0o644)
    subprocess.call(shlex.split('systemctl enable slurmd'))

# END install_compute_service_scripts()


def setup_bash_profile():

    with open('/etc/profile.d/slurm.sh', 'w') as f:
        f.write("""
S_PATH={}
PATH=$PATH:$S_PATH/bin:$S_PATH/sbin
""".format(CURR_SLURM_DIR))

    if INSTANCE_TYPE == 'compute':
        hostname = socket.gethostname()
        pid = int(hostname[-6:-4])
        if PARTITIONS[pid]['gpu_count']:
            with open('/etc/profile.d/cuda.sh', 'w') as f:
                f.write("""
CUDA_PATH=/usr/local/cuda
PATH=$CUDA_PATH/bin${PATH:+:${PATH}}
LD_LIBRARY_PATH=$CUDA_PATH/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
""")

# END setup_bash_profile()


def setup_nfs_apps_vols():

    with open('/etc/fstab', 'a') as f:
        if not NFS_APPS_SERVER:
            if INSTANCE_TYPE != 'controller':
                f.write("\n{1}:{0} \t{0} \tnfs \trw,hard,intr \t0 \t0"
                        .format(APPS_DIR, CONTROL_MACHINE))
        else:
            f.write("\n{1}:{2} \t{0} \tnfs \trw,hard,intr \t0 \t0\n"
                    .format(APPS_DIR, NFS_APPS_SERVER, NFS_APPS_DIR))

# END setup_nfs_apps_vols()


def setup_nfs_home_vols():

    with open('/etc/fstab', 'a') as f:
        if not NFS_HOME_SERVER:
            if ((INSTANCE_TYPE != 'controller')):
                f.write("\n{0}:/home \t/home \tnfs \trw,hard,intr \t0 \t0"
                        .format(CONTROL_MACHINE))
        else:
            f.write("\t{0}:{1} \t/home \tnfs \trw,hard,intr \t0 \t0"
                    .format(NFS_HOME_SERVER, NFS_HOME_DIR))

# END setup_nfs_home_vols()


def setup_nfs_sec_vols():
    if CONTROLLER_SECONDARY_DISK and (INSTANCE_TYPE != 'controller'):
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
        print("Waiting for " + APPS_DIR + " and /home to be mounted")
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

    os.system(("echo '*/1 * * * * {}/slurm/scripts/slurm-gcp-sync.py' "
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
    pid = int(hostname[-6:-4])
    if PARTITIONS[pid]['gpu_count']:
        time.sleep(300)

    print("Creating compute image...")
    subprocess.call(shlex.split(
        "gcloud compute images create {0}-compute-image-{4}-{3} "
        "--source-disk {1} --source-disk-zone {2} --force "
        "--family {0}-compute-image-{4}-family"
        .format(CLUSTER_NAME, hostname, PARTITIONS[pid]["zone"], ver, pid)))
# END create_compute_image()


def setup_selinux():

    subprocess.call(shlex.split('setenforce 0'))
    with open('/etc/selinux/config', 'w') as f:
        f.write("""
SELINUX=permissive
SELINUXTYPE=targeted
""")
# END setup_selinux()


def remove_startup_scripts(hostname):

    if CLUSTER_NAME + '-compute-image' in hostname:
        pid = int(hostname[-6:-4])
        subprocess.call(shlex.split(
           "gcloud compute instances remove-metadata {} --zone={} "
           "--keys=startup-script".format(hostname, PARTITIONS[pid]["zone"])))

    elif INSTANCE_TYPE == 'controller':
        # controller
        subprocess.call(shlex.split(
            "gcloud compute instances remove-metadata {} --zone={} "
            "--keys=startup-script".format(hostname, ZONE)))
        # logins
        for i in range(1, LOGIN_NODE_COUNT + 1):
            subprocess.call(shlex.split(
                "gcloud compute instances remove-metadata {}-login{} "
                "--zone={} --keys=startup-script"
                .format(CLUSTER_NAME, i, ZONE)))

        # computes
        for i, part in enumerate(PARTITIONS):
            if not part['static_node_count']:
                continue
            for j in range(part['static_node_count']):
                subprocess.call(shlex.split(
                    "gcloud compute instances remove-metadata {}-compute{:06} "
                    "--zone={} --keys=startup-script"
                    .format(CLUSTER_NAME, i * MAX_PARTITION_SIZE + j,
                            part['zone'])))
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

    if INSTANCE_TYPE == 'compute':
        while not have_internet():
            print("Waiting for internet connection")

    if not os.path.exists(APPS_DIR + '/slurm'):
        os.makedirs(APPS_DIR + '/slurm')
        print("ww Created Slurm Folders")

    if CONTROLLER_SECONDARY_DISK:
        if not os.path.exists(SEC_DISK_DIR):
            os.makedirs(SEC_DISK_DIR)

    start_motd()

    if not os.path.exists('/var/log/slurm'):
        os.makedirs('/var/log/slurm')

    add_slurm_user()
    install_packages()
    setup_munge()
    setup_bash_profile()
    setup_modules()

    if CONTROLLER_SECONDARY_DISK and (INSTANCE_TYPE == 'controller'):
        setup_secondary_disks()

    setup_nfs_apps_vols()
    setup_nfs_home_vols()
    setup_nfs_sec_vols()

    if INSTANCE_TYPE == 'controller':
        mount_nfs_vols()
        start_munge()
        install_slurm()

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

        oslogin_chars = ['@', '.']

        SLURM_USERS = DEF_SLURM_USERS

        for char in oslogin_chars:
            SLURM_USERS = SLURM_USERS.replace(char, '_')

        sacctmgr = CURR_SLURM_DIR + "/bin/sacctmgr -i"
        subprocess.call(shlex.split(sacctmgr + " add cluster " + CLUSTER_NAME))
        subprocess.call(shlex.split(sacctmgr + " add account " + DEF_SLURM_ACCT))
        subprocess.call(shlex.split(sacctmgr + " add user {} account={}"
                                    .format(SLURM_USERS, DEF_SLURM_ACCT)))

        subprocess.call(shlex.split("systemctl enable slurmctld"))
        subprocess.call(shlex.split("systemctl start slurmctld"))
        setup_nfs_threads()
        # Export at the end to signal that everything is up
        subprocess.call(shlex.split("systemctl enable nfs-server"))
        subprocess.call(shlex.split("systemctl start nfs-server"))
        setup_nfs_exports()

        setup_sync_cronjob()

        # DOWN partitions until image is created.
        for part in PARTITIONS:
            subprocess.call(shlex.split(
                "{}/bin/scontrol update partitionname={} state=down".format(
                    CURR_SLURM_DIR, part['name'])))

        print("ww Done installing controller")
    elif INSTANCE_TYPE == 'compute':
        install_compute_service_scripts()
        setup_slurmd_cronjob()
        mount_nfs_vols()
        start_munge()
        setup_nss_slurm()

        try:
            subprocess.call('{}/slurm/scripts/custom-compute-install'
                            .format(APPS_DIR))
        except Exception:
            # Ignore blank files with no shell magic.
            pass

        if CLUSTER_NAME + '-compute-image' in hostname:

            create_compute_image()

            pid = int(hostname[-6:-4])
            subprocess.call(shlex.split(
                "{}/bin/scontrol update partitionname={} state=up".format(
                    CURR_SLURM_DIR, PARTITIONS[pid]['name'])))

            remove_startup_scripts(hostname)

            subprocess.call(shlex.split(
                "gcloud compute instances stop {} --zone {} --quiet"
                .format(hostname, PARTITIONS[pid]['zone'])))
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

    end_motd()

# END main()


if __name__ == '__main__':
    main()
