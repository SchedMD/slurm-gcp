#!/usr/bin/python

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

import httplib
import os
import shlex
import socket
import subprocess
import time
import urllib
import urllib2

CLUSTER_NAME      = '@CLUSTER_NAME@'
MACHINE_TYPE      = '@MACHINE_TYPE@' # e.g. n1-standard-1, n1-starndard-2
INSTANCE_TYPE     = '@INSTANCE_TYPE@' # e.g. controller, login, compute

PROJECT           = '@PROJECT@'
ZONE              = '@ZONE@'

APPS_DIR          = '/apps'
MUNGE_KEY         = '@MUNGE_KEY@'
SLURM_VERSION     = '@SLURM_VERSION@'
STATIC_NODE_COUNT = @STATIC_NODE_COUNT@
MAX_NODE_COUNT    = @MAX_NODE_COUNT@
DEF_SLURM_ACCT    = '@DEF_SLURM_ACCT@'
DEF_SLURM_USERS   = '@DEF_SLURM_USERS@'
EXTERNAL_COMPUTE_IPS = @EXTERNAL_COMPUTE_IPS@
GPU_TYPE          = '@GPU_TYPE@'
GPU_COUNT         = @GPU_COUNT@
NFS_APPS_SERVER   = '@NFS_APPS_SERVER@'
NFS_HOME_SERVER   = '@NFS_HOME_SERVER@'
CONTROLLER_SECONDARY_DISK = @CONTROLLER_SECONDARY_DISK@
SEC_DISK_DIR      = '/mnt/disks/sec'

CONTROL_MACHINE = CLUSTER_NAME + '-controller'

SLURM_PREFIX  = APPS_DIR + '/slurm/slurm-' + SLURM_VERSION

MOTD_HEADER = '''

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


'''

def add_slurm_user():

    SLURM_UID = str(992)
    subprocess.call(['groupadd', '-g', SLURM_UID, 'slurm'])
    subprocess.call(['useradd', '-m', '-c', 'SLURM Workload Manager',
        '-d', '/var/lib/slurm', '-u', SLURM_UID, '-g', 'slurm',
        '-s', '/bin/bash', 'slurm'])

# END add_slurm_user()


def start_motd():

    msg = MOTD_HEADER + """
*** Slurm is currently being installed/configured in the background. ***
A terminal broadcast will announce when installation and configuration is
complete.

"""

    if INSTANCE_TYPE != "controller":
        msg += """/home on the controller will be mounted over the existing /home.
Any changes in /home will be hidden. Please wait until the installation is
complete before making changes in your home directory.

"""

    f = open('/etc/motd', 'w')
    f.write(msg)
    f.close()

# END start_motd()


def end_motd():

    f = open('/etc/motd', 'w')
    f.write(MOTD_HEADER)
    f.close()

    subprocess.call(['wall', '-n',
        '*** Slurm ' + INSTANCE_TYPE + ' daemon installation complete ***'])

    if INSTANCE_TYPE != "controller":
        subprocess.call(['wall', '-n', """
/home on the controller was mounted over the existing /home.
Either log out and log back in or cd into ~.
"""])

#END start_motd()


def have_internet():
    conn = httplib.HTTPConnection("www.google.com", timeout=1)
    try:
        conn.request("HEAD", "/")
        conn.close()
        return True
    except:
        conn.close()
        return False

#END have_internet()


def install_packages():

    packages = ['bind-utils',
                'epel-release',
                'gcc',
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

    while subprocess.call(['yum', 'install', '-y'] + packages):
        print "yum failed to install packages. Trying again in 5 seconds"
        time.sleep(5)

    while subprocess.call(['pip', 'install', '--upgrade',
        'google-api-python-client']):
        print "failed to install google python api client. Trying again 5 seconds."
        time.sleep(5)

    if GPU_COUNT and (INSTANCE_TYPE == "compute"):
        rpm = "cuda-repo-rhel7-9.2.148-1.x86_64.rpm"
        subprocess.call("yum -y install kernel-devel-$(uname -r) kernel-headers-$(uname -r)", shell=True)
        subprocess.call(shlex.split("wget http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/" + rpm))
        subprocess.call(shlex.split("sudo rpm -i " + rpm))
        subprocess.call(shlex.split("sudo yum clean all"))
        subprocess.call(shlex.split("sudo yum -y install cuda"))
        subprocess.call(shlex.split("nvidia-smi")) # Creates the device files

#END install_packages()

def setup_munge():

    MUNGE_DIR = "/etc/munge"

    f = open('/etc/fstab', 'a')
    if not NFS_APPS_SERVER:
        if ((INSTANCE_TYPE != "controller")):
            f.write("""
{1}:{0}    {0}     nfs      rw,sync,hard,intr  0     0
""".format(MUNGE_DIR, CONTROL_MACHINE))
    else:
        f.write("""
{1}:{0}    {0}     nfs      rw,sync,hard,intr  0     0
""".format(MUNGE_DIR, NFS_APPS_SERVER))
    f.close()

    if (INSTANCE_TYPE != "controller"):
        return

    if MUNGE_KEY:
        f = open(MUNGE_DIR +'/munge.key', 'w')
        f.write(MUNGE_KEY)
        f.close()

        subprocess.call(['chown', '-R', 'munge:', MUNGE_DIR, '/var/log/munge/'])
        os.chmod(MUNGE_DIR + '/munge.key' ,0o400)
        os.chmod(MUNGE_DIR                ,0o700)
        os.chmod('/var/log/munge/'        ,0o700)
    else:
        subprocess.call(['create-munge-key'])

#END setup_munge ()

def start_munge():
        subprocess.call(['systemctl', 'enable', 'munge'])
        subprocess.call(['systemctl', 'start', 'munge'])
#END start_munge()

def setup_nfs_exports():

    f = open('/etc/exports', 'w')
    f.write("""
/home  *(rw,sync,no_subtree_check,no_root_squash)
%s  *(rw,sync,no_subtree_check,no_root_squash)
/etc/munge *(rw,sync,no_subtree_check,no_root_squash)
""" % APPS_DIR)
    if CONTROLLER_SECONDARY_DISK:
        f.write("""
%s  *(rw,sync,no_subtree_check,no_root_squash)
""" % SEC_DISK_DIR)
    f.close()

    subprocess.call(shlex.split("exportfs -a"))

#END setup_nfs_exports()


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
    machine = {'sockets': 1, 'cores': 1, 'threads': 1, 'memory': 1}

    try:
        compute = googleapiclient.discovery.build('compute', 'v1',
                                                  cache_discovery=False)
        type_resp = compute.machineTypes().get(project=PROJECT, zone=ZONE,
                machineType=MACHINE_TYPE).execute()
        if type_resp:
            tot_cpus = type_resp['guestCpus']
            if tot_cpus > 1:
                machine['cores']   = tot_cpus / 2
                machine['threads'] = 2

            # Because the actual memory on the host will be different than what
            # is configured (e.g. kernel will take it). From experiments, about
            # 16 MB per GB are used (plus about 400 MB buffer for the first
            # couple of GB's. Using 30 MB to be safe.
            gb = type_resp['memoryMb'] / 1024;
            machine['memory'] = type_resp['memoryMb'] - (400 + (gb * 30))

    except Exception, e:
        print "Failed to get MachineType '%s' from google api (%s)" % (MACHINE_TYPE, str(e))

    return machine
#END expand_machine_type()


def install_slurm_conf():

    machine = expand_machine_type()
    def_mem_per_cpu = max(100,
            (machine['memory'] /
             (machine['threads']*machine['cores']*machine['sockets'])))

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
#CheckpointType=checkpoint/none
CryptoType=crypto/munge
#DisableRootJobs=NO
#EnforcePartLimits=NO
#Epilog=
#EpilogSlurmctld=
#FirstJobId=1
#MaxJobId=999999
GresTypes=gpu
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
SlurmctldPort=6817
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
#MessageTimeout=10
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
DefMemPerCPU={def_mem_per_cpu}
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
DebugFlags=power
#JobCompHost=
#JobCompLoc=
#JobCompPass=
#JobCompPort=
JobCompType=jobcomp/none
#JobCompUser=
#JobContainerType=job_container/none
JobAcctGatherFrequency=30
JobAcctGatherType=jobacct_gather/none
SlurmctldDebug=info
SlurmctldLogFile={apps_dir}/slurm/log/slurmctld.log
SlurmdDebug=debug
SlurmdLogFile=/var/log/slurm/slurmd-%n.log
#
#
# POWER SAVE SUPPORT FOR IDLE NODES (optional)
SuspendProgram={apps_dir}/slurm/scripts/suspend.py
ResumeProgram={apps_dir}/slurm/scripts/resume.py
SuspendTimeout=300
ResumeTimeout=1800
#ResumeRate=
#SuspendExcNodes=
#SuspendExcParts=
SuspendRate=0
SuspendTime=2100
#
#
# COMPUTE NODES
""".format(apps_dir        = APPS_DIR,
           cluster_name    = CLUSTER_NAME,
           control_machine = CONTROL_MACHINE,
           def_mem_per_cpu = def_mem_per_cpu)

    conf += ' '.join(("NodeName=DEFAULT",
                      "Sockets="        + str(machine['sockets']),
                      "CoresPerSocket=" + str(machine['cores']),
                      "ThreadsPerCore=" + str(machine['threads']),
                      "RealMemory="     + str(machine['memory']),
                      "State=UNKNOWN"))

    if GPU_COUNT:
        conf += " Gres=gpu:" + str(GPU_COUNT)
    conf += "\n"

    static_range = ""
    if STATIC_NODE_COUNT and STATIC_NODE_COUNT > 1:
        static_range = "[1-%d]" % STATIC_NODE_COUNT
    elif STATIC_NODE_COUNT:
        static_range = "1"

    cloud_range = ""
    if MAX_NODE_COUNT and (MAX_NODE_COUNT != STATIC_NODE_COUNT):
        cloud_range = "[%d-%d]" % (STATIC_NODE_COUNT+1, MAX_NODE_COUNT)

    if static_range:
        conf += """
SuspendExcNodes={1}-compute{0}
NodeName={1}-compute{0}
""".format(static_range, CLUSTER_NAME)

    if cloud_range:
        conf += "NodeName={0}-compute{1} State=CLOUD".format(CLUSTER_NAME, cloud_range)

    conf += """
PartitionName=debug Nodes={0}-compute[1-{1:d}] Default=YES MaxTime=INFINITE State=UP
""".format(CLUSTER_NAME, MAX_NODE_COUNT)

    etc_dir = SLURM_PREFIX + '/etc'
    if not os.path.exists(etc_dir):
        os.makedirs(etc_dir)
    f = open(etc_dir + '/slurm.conf', 'w')
    f.write(conf)
    f.close()
#END install_slurm_conf()


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

StorageLoc=slurm_acct_db

StorageType=accounting_storage/mysql
#StorageUser=database_mgr
#StoragePass=shazaam

""".format(apps_dir = APPS_DIR, control_machine = CONTROL_MACHINE)
    etc_dir = SLURM_PREFIX + '/etc'
    if not os.path.exists(etc_dir):
        os.makedirs(etc_dir)
    f = open(etc_dir + '/slurmdbd.conf', 'w')
    f.write(conf)
    f.close()

#END install_slurmdbd_conf()


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

    etc_dir = SLURM_PREFIX + '/etc'
    f = open(etc_dir + '/cgroup.conf', 'w')
    f.write(conf)
    f.close()

    f = open(etc_dir + '/cgroup_allowed_devices_file.conf', 'w')
    f.write("")
    f.close()

    if GPU_COUNT:
        f = open(etc_dir + '/gres.conf', 'w')
        f.write("NodeName=%s-compute[1-%d] Name=gpu File=/dev/nvidia[0-%d]"
                % (CLUSTER_NAME, MAX_NODE_COUNT, (GPU_COUNT - 1)))
        f.close()
#END install_cgroup_conf()


def install_suspend_progs():

    if not os.path.exists(APPS_DIR + '/slurm/scripts'):
        os.makedirs(APPS_DIR + '/slurm/scripts')

    GOOGLE_URL = "http://metadata.google.internal/computeMetadata/v1/instance/attributes"

    # Suspend
    req = urllib2.Request(GOOGLE_URL + '/slurm_suspend')
    req.add_header('Metadata-Flavor', 'Google')
    resp = urllib2.urlopen(req)

    f = open(APPS_DIR + '/slurm/scripts/suspend.py', 'w')
    f.write(resp.read())
    f.close()
    os.chmod(APPS_DIR + '/slurm/scripts/suspend.py', 0o755)

    # Resume
    req = urllib2.Request(GOOGLE_URL + '/slurm_resume')
    req.add_header('Metadata-Flavor', 'Google')
    resp = urllib2.urlopen(req)

    f = open(APPS_DIR + '/slurm/scripts/resume.py', 'w')
    f.write(resp.read())
    f.close()
    os.chmod(APPS_DIR + '/slurm/scripts/resume.py', 0o755)

    # Startup script
    req = urllib2.Request(GOOGLE_URL + '/startup-script-compute')
    req.add_header('Metadata-Flavor', 'Google')
    resp = urllib2.urlopen(req)

    f = open(APPS_DIR + '/slurm/scripts/startup-script.py', 'w')
    f.write(resp.read())
    f.close()
    os.chmod(APPS_DIR + '/slurm/scripts/startup-script.py', 0o755)

#END install_suspend_progs()

def install_slurm():

    SCHEDMD_URL = 'https://download.schedmd.com/slurm/'
    file = "slurm-%s.tar.bz2" % SLURM_VERSION
    urllib.urlretrieve(SCHEDMD_URL + file, '/tmp/' + file)

    prev_path = os.getcwd()

    os.chdir('/tmp')
    subprocess.call(['tar', '-xvjf', file])
    os.chdir('/tmp/slurm-' + SLURM_VERSION)
    if not os.path.exists('build'):
        os.makedirs('build')
    os.chdir('build')
    subprocess.call(['../configure', '--prefix=%s' % SLURM_PREFIX,
                     '--sysconfdir=%s/slurm/current/etc' % APPS_DIR])
    subprocess.call(['make', '-j', 'install'])

    subprocess.call(shlex.split("ln -s %s %s/slurm/current" % (SLURM_PREFIX, APPS_DIR)))

    os.chdir(prev_path)

    if not os.path.exists(APPS_DIR + '/slurm/state'):
        os.makedirs(APPS_DIR + '/slurm/state')
        subprocess.call(['chown', '-R', 'slurm:', APPS_DIR + '/slurm/state'])
    if not os.path.exists(APPS_DIR + '/slurm/log'):
        os.makedirs(APPS_DIR + '/slurm/log')
        subprocess.call(['chown', '-R', 'slurm:', APPS_DIR + '/slurm/log'])

    install_slurm_conf()
    install_slurmdbd_conf()
    install_cgroup_conf()
    install_suspend_progs()

#END install_slurm()

def install_slurm_tmpfile():

    run_dir = '/var/run/slurm'

    f = open('/etc/tmpfiles.d/slurm.conf', 'w')
    f.write("""
d %s 0755 slurm slurm -
""" % run_dir)
    f.close()

    if not os.path.exists(run_dir):
        os.makedirs(run_dir)

    os.chmod(run_dir, 0o755)
    subprocess.call(['chown', 'slurm:', run_dir])

#END install_slurm_tmpfile()

def install_controller_service_scripts():

    install_slurm_tmpfile()

    # slurmctld.service
    f = open('/usr/lib/systemd/system/slurmctld.service', 'w')
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
""".format(prefix = SLURM_PREFIX))
    f.close()

    os.chmod('/usr/lib/systemd/system/slurmctld.service', 0o644)

    # slurmdbd.service
    f = open('/usr/lib/systemd/system/slurmdbd.service', 'w')
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
""".format(prefix = APPS_DIR + "/slurm/current"))
    f.close()

    os.chmod('/usr/lib/systemd/system/slurmdbd.service', 0o644)

#END install_controller_service_scripts()


def install_compute_service_scripts():

    install_slurm_tmpfile()

    # slurmd.service
    f = open('/usr/lib/systemd/system/slurmd.service', 'w')
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
""".format(prefix = APPS_DIR + "/slurm/current"))
    f.close()

    os.chmod('/usr/lib/systemd/system/slurmd.service', 0o644)

#END install_compute_service_scripts()


def setup_bash_profile():

    f = open('/etc/profile.d/slurm.sh', 'w')
    f.write("""
S_PATH=%s/slurm/current
PATH=$PATH:$S_PATH/bin:$S_PATH/sbin
""" % APPS_DIR)
    f.close()

    if GPU_COUNT and (INSTANCE_TYPE == "compute"):
        f = open('/etc/profile.d/cuda.sh', 'w')
        f.write("""
CUDA_PATH=/usr/local/cuda
PATH=$CUDA_PATH/bin${PATH:+:${PATH}}
LD_LIBRARY_PATH=$CUDA_PATH/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
""")
        f.close()

#END setup_bash_profile()

def setup_nfs_apps_vols():

    f = open('/etc/fstab', 'a')
    if not NFS_APPS_SERVER:
        if ((INSTANCE_TYPE != "controller")):
            f.write("""
{1}:{0}    {0}     nfs      rw,sync,hard,intr  0     0
""".format(APPS_DIR, CONTROL_MACHINE))
    else:
        f.write("""
{1}:{0}    {0}     nfs      rw,sync,hard,intr  0     0
""".format(APPS_DIR, NFS_APPS_SERVER))
    f.close()

#END setup_nfs_apps_vols()

def setup_nfs_home_vols():

    f = open('/etc/fstab', 'a')
    if not NFS_HOME_SERVER:
        if ((INSTANCE_TYPE != "controller")):
            f.write("""
{0}:/home    /home     nfs      rw,sync,hard,intr  0     0
""".format(CONTROL_MACHINE))
    else:
        f.write("""
{0}:/home    /home     nfs      rw,sync,hard,intr  0     0
""".format(NFS_HOME_SERVER))
    f.close()

#END setup_nfs_home_vols()

def setup_nfs_sec_vols():
    f = open('/etc/fstab', 'a')

    if CONTROLLER_SECONDARY_DISK:
        if ((INSTANCE_TYPE != "controller")):
            f.write("""
{1}:{0}    {0}     nfs      rw,sync,hard,intr  0     0
""".format(SEC_DISK_DIR, CONTROL_MACHINE))
    f.close()

#END setup_nfs_sec_vols()

def setup_secondary_disks():

    subprocess.call(shlex.split("sudo mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb"))
    f = open('/etc/fstab', 'a')

    f.write("""
/dev/sdb    {0}  ext4    discard,defaults,nofail  0  2
""".format(SEC_DISK_DIR))
    f.close()

#END setup_secondary_disks()

def mount_nfs_vols():
    while subprocess.call(['mount', '-a']):
        print "Waiting for " + APPS_DIR + " and /home to be mounted"
        time.sleep(5)

#END mount_nfs_vols()

# Tune the NFS server to support many mounts
def setup_nfs_threads():

    f = open('/etc/sysconfig/nfs', 'a')
    f.write("""
# Added by Google
RPCNFSDCOUNT=256
""".format(APPS_DIR))
    f.close()

# END setup_nfs_threads()

def setup_slurmd_cronjob():
    #subprocess.call(shlex.split('crontab < /apps/slurm/scripts/cron'))
    os.system("echo '*/2 * * * * if [ `systemctl status slurmd | grep -c inactive` -gt 0 ]; then mount -a; systemctl restart slurmd; fi' | crontab -u root -")
# END setup_slurmd_cronjob()

def format_disk():
    subprocess.call(shlex.split("sudo mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb"))
    #subprocess.call(shlex.split("sudo mkdir -p " + SEC_DISK_DIR))
    subprocess.call(shlex.split("sudo mount -o discard,defaults /dev/sdb " + SEC_DISK_DIR))
    subprocess.call(shlex.split("sudo chmod a+w " + SEC_DISK_DIR))

# END format_disk()

def main():
    # Disable SELinux
    subprocess.call(shlex.split('setenforce 0'))

    if ((INSTANCE_TYPE == "controller") and  not EXTERNAL_COMPUTE_IPS):
        # Setup a NAT gateway for the compute instances to get internet from.
        subprocess.call(shlex.split("sysctl -w net.ipv4.ip_forward=1"))
        subprocess.call(shlex.split("firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -o eth0 -j MASQUERADE"))
        subprocess.call(shlex.split("firewall-cmd --reload"))
        subprocess.call(shlex.split("echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf"))

    if INSTANCE_TYPE == "compute":
        while not have_internet():
            print "Waiting for internet connection"

    if not os.path.exists(APPS_DIR + '/slurm'):
        os.makedirs(APPS_DIR + '/slurm')
        print "ww Created Slurm Folders"

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

    if (CONTROLLER_SECONDARY_DISK and (INSTANCE_TYPE == "controller")):
        setup_secondary_disks()

    setup_nfs_apps_vols()
    setup_nfs_home_vols()
    setup_nfs_sec_vols()
    mount_nfs_vols()

    start_munge()

    if INSTANCE_TYPE == "controller":

        install_slurm()

        # Add any additional installation functions here

        install_controller_service_scripts()

        subprocess.call(shlex.split('systemctl enable mariadb'))
        subprocess.call(shlex.split('systemctl start mariadb'))

        subprocess.call(['mysql', '-u', 'root', '-e',
            "create user 'slurm'@'localhost'"])
        subprocess.call(['mysql', '-u', 'root', '-e',
            "grant all on slurm_acct_db.* TO 'slurm'@'localhost';"])
        subprocess.call(['mysql', '-u', 'root', '-e',
            "grant all on slurm_acct_db.* TO 'slurm'@'{0}';".format(CONTROL_MACHINE)])

        subprocess.call(shlex.split('systemctl enable slurmdbd'))
        subprocess.call(shlex.split('systemctl start slurmdbd'))

        # Wait for slurmdbd to come up
        time.sleep(5)

        oslogin_chars = ['@', '.']

        SLURM_USERS = DEF_SLURM_USERS

        for char in oslogin_chars:
            SLURM_USERS = SLURM_USERS.replace(char, '_')

        subprocess.call(shlex.split(SLURM_PREFIX + '/bin/sacctmgr -i add cluster ' + CLUSTER_NAME))
        subprocess.call(shlex.split(SLURM_PREFIX + '/bin/sacctmgr -i add account ' + DEF_SLURM_ACCT))
        subprocess.call(shlex.split(SLURM_PREFIX + '/bin/sacctmgr -i add user ' + SLURM_USERS + ' account=' + DEF_SLURM_ACCT))

        subprocess.call(shlex.split('systemctl enable slurmctld'))
        subprocess.call(shlex.split('systemctl start slurmctld'))
        setup_nfs_threads()
        # Export at the end to signal that everything is up
        subprocess.call(shlex.split('systemctl enable nfs-server'))
        subprocess.call(shlex.split('systemctl start nfs-server'))
        setup_nfs_exports()
        print "ww Done installing controller"
        subprocess.call(shlex.split('gcloud compute instances remove-metadata '+ CONTROL_MACHINE + ' --zone=' + ZONE + ' --keys=startup-script'))

    elif INSTANCE_TYPE == "compute":
        install_compute_service_scripts()

        hostname = socket.gethostname()

        # Add any additional installation functions here

        subprocess.call(shlex.split('systemctl enable slurmd'))
        setup_slurmd_cronjob()
        subprocess.call(shlex.split('systemctl start slurmd'))
        subprocess.call(shlex.split('gcloud compute instances remove-metadata '+ hostname + ' --zone=' + ZONE + ' --keys=startup-script'))

    end_motd()

# END main()


if __name__ == '__main__':
    main()
