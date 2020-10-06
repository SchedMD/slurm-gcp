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
import shutil
import sys
import time
import urllib.request
from pathlib import Path
from subprocess import DEVNULL

import googleapiclient.discovery
import requests


SCRIPTSDIR = Path('/root/image-scripts')
SCRIPTSDIR.mkdir(parents=True, exist_ok=True)
# get util.py from metadata
UTIL_FILE = SCRIPTSDIR/'util.py'
if not UTIL_FILE.exists():
    print(f"{UTIL_FILE} not found, attempting to fetch from metadata")
    try:
        resp = requests.get('http://metadata.google.internal/computeMetadata/v1/instance/attributes/util-script',
                            headers={'Metadata-Flavor': 'Google'})
        resp.raise_for_status()
        UTIL_FILE.write_text(resp.text)
    except requests.exceptions.RequestException:
        print("util.py script not found in metadata either, aborting")
        sys.exit(1)

spec = importlib.util.spec_from_file_location('util', UTIL_FILE)
util = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = util
spec.loader.exec_module(util)
cd = util.cd  # import util.cd into local namespace

util.config_root_logger(file=str(SCRIPTSDIR/'setup.log'))
log = logging.getLogger(Path(__file__).name)

class Config(util.NSDict):
    """ Loads config from yaml and holds values in nested namespaces """

    def __init__(self, *args, **kwargs):
        super(Config, self).__init__(*args, **kwargs)

    @util.cached_property
    def slurm_version(self):
        # match 'b:<branch_name>' or eg. '20.02-latest', '20.02.0', '20.02.0-1'
        #patt = re.compile(r'(b:\S+)|((\d+[\.-])+\w+)')
        version = yaml.safe_load(util.get_metadata('attributes/slurm_version'))
        return version

    @cached_property
    def zone(self):
        return get_metadata('zone')

    @cached_property
    def hostname(self):
        return socket.gethostname()

    @cached_property
    def os_name(self):
        os_rel = Path('/etc/os-release').read_text()
        os_info = dict(s.split('=') for s in shlex.split(os_rel))
        return "{ID}{VERSION_ID}".format(**os_info).replace('.', '')

    @property
    def region(self):
        return self.zone and '-'.join(self.zone.split('-')[:-1])

    @property
    def pacman(self):
        yum = "yum install -y"
        apt = "apt-get install -y"
        return {
            'centos7': yum,
            'centos8': yum,
            'debian9': apt,
            'debian10': apt,
            'ubuntu2004': apt,
        }[self.os_name]

    def __getattr__(self, item):
        """ only called if item is not found in self """
        return None
# get setup config from metadata
#config_yaml = yaml.safe_load(util.get_metadata('attributes/config'))
#if not util.get_metadata('attributes/terraform'):
#    config_yaml = yaml.safe_load(config_yaml)
cfg = util.Config()

dirs = util.NSDict({n: Path(p) for n, p in dict.items({
    'slurm': '/slurm',
    'install': '/usr/local',
    'apps': '/apps',
    'munge': '/etc/munge',
})})

for p in dirs.values():
    p.mkdir(parents=True, exist_ok=True)

slurmdirs = util.NSDict({n: Path(p) for n, p in dict.items({
    'etc': '/usr/local/etc/slurm',
    'log': '/var/log/slurm',
    'state': '/var/spool/slurmctld',
    'run': '/var/run/slurm',
})})

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
    """ Create user slurm """
    util.run("useradd -m -c SlurmUser -d /var/lib/slurm -U -r slurm")


def setup_modules():
    """ Add /apps/modulefiles as environment module dir """

    appsmfs = Path('/apps/modulefiles')
    modulespath = Path('/usr/share/Modules/init/.modulespath')
    if not modulespath.exists():
        modulespath = Path('/usr/share/modules/init/.modulespath')

    with modulespath.open('r+') as dotmp:
        if str(appsmfs) not in dotmp.read():
            if not appsmfs.is_dir():
                appsmfs.mkdir(parents=True)
            # after read, file cursor is at end of file
            dotmp.write(f'\n{appsmfs}\n')


def start_motd():
    """ Write out MOTD to /etc/motd """
    # TODO do we need a motd in the image creation instance?
    pass


def end_motd(broadcast=True):
    """ Change MOTD to indicate that installation is done """

    Path('/etc/motd').write_text(MOTD_HEADER)

    if not broadcast:
        return

    util.run("wall -n '*** Slurm installation complete ***'")


def install_slurmlog_conf():
    """ Install fluentd config for slurm logs """

    slurmlog_config = util.get_metadata('attributes/fluentd-conf')
    if slurmlog_config:
        conf_file = Path('/etc/google-fluentd/config.d')
        (conf_file/'slurmlogs.conf').write_text(slurmlog_config)


def install_lustre():
    """ Install lustre client drivers """
    lustre_url = 'https://downloads.whamcloud.com/public/lustre/latest-release/el7.7.1908/client/RPMS/x86_64/'
    lustre_tmp = Path('/tmp/lustre')
    lustre_tmp.mkdir(parents=True)
    util.run('yum update -y')
    util.run('yum install -y wget libyaml')
    for rpm in ('kmod-lustre-client-2*.rpm', 'lustre-client-2*.rpm'):
        util.run(
            f"wget -r -l1 --no-parent -A '{rpm}' '{lustre_url}' -P {lustre_tmp}")
    util.run(
        f"find {lustre_tmp} -name '*.rpm' -execdir rpm -ivh {{}} ';'")
    util.run(f"rm -rf {lustre_tmp}")
    util.run("modprobe lustre")


def install_gcsfuse():
    """ Instal gcsfuse driver """
    if cfg.os_name in ('centos7', 'centos8', 'rhel7', 'rhel8'):
        Path('/etc/yum.repos.d/gcsfuse.repo').write_text("""
[gcsfuse]
name=gcsfuse (packages.cloud.google.com)
baseurl=https://packages.cloud.google.com/yum/repos/gcsfuse-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
""")
        util.run("yum install -y gcsfuse")
    elif cfg.os_name in ('debian10', 'ubuntu2004'):
        release = util.run("lsb_release -cs", get_stdout=True).stdout.rstrip()
        repo = f'gcsfuse-{release}'
        Path('/etc/apt/sources.list.d/gcsfuse.list').write_text(
            f"deb https://packages.cloud.google.com/apt {repo} main"
        )
        key_url = 'https://packages.cloud.google.com/apt/doc/apt-key.gpg'
        util.run("apt-key add -", input=requests.get(key_url).text)
        util.run("apt-get update")
        util.run("apt-get install -y gcsfuse")


def install_cuda():
    """ Install cuda """
    if cfg.os_name in ('centos7', 'centos8'):
        vers = 'rhel' + cfg.os_name[-1]
        repo = f'http://developer.download.nvidia.com/compute/cuda/repos/{vers}/x86_64/cuda-{vers}.repo'
        util.run(f"yum-config-manager --add-repo {repo}")
        util.run("yum clean all")
        util.run("yum -y install nvidia-driver-latest-dkms cuda")
        util.run("yum -y install cuda-drivers")
        # Creates the device files
    elif cfg.os_name == 'debian10':
        util.run("apt-get install linux-headers-$(uname -r)")
        repo = 'https://developer.download.nvidia.com/compute/cuda/repos/debian10/x86_64/'
        util.run(f"add-apt-repository 'deb {repo} /'")
        util.run("add-apt-repository contrib")
        util.run("apt-get update")
        util.run("apt-get -y install cuda")
    elif cfg.os_name == 'ubuntu2004':
        pin_url = 'https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin'
        pinfile = Path('/etc/apt/preferences.d/cuda-repository-pin')
        pinfile.write_text(requests.get(pin_url).text)

        key_url = 'https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/7fa2af80.pub'
        util.run(f"apt-key adv --fetch-keys {key_url}")

        repo_url = 'https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/'
        util.run(f"add-apt-repository 'deb {repo_url} /'")
        util.run("apt-get update")
        util.run("apt-get -y install cuda")


def install_packages():
    """ Install all packages using the system package manager """

    packages = util.get_metadata('attributes/packages').splitlines()
    util.run(f"{cfg.pacman} {' '.join(packages)}")

    if cfg.os_name in ('centos7', 'centos8'):
        install_lustre()
    install_gcsfuse()
    install_cuda()
        
    # install stackdriver monitoring and logging
    add_mon_script = Path('/tmp/add-monitoring-agent-repo.sh')
    add_mon_url = f'https://dl.google.com/cloudagents/{add_mon_script.name}'
    urllib.request.urlretrieve(add_mon_url, add_mon_script)
    util.run(f"bash {add_mon_script}")
    util.run(f"{cfg.pacman} stackdriver-agent")

    add_log_script = Path('/tmp/install-logging-agent.sh')
    add_log_url = f'https://dl.google.com/cloudagents/{add_log_script.name}'
    urllib.request.urlretrieve(add_log_url, add_log_script)
    util.run(f"bash {add_log_script}")
    install_slurmlog_conf()

    util.run("systemctl enable stackdriver-agent google-fluentd")
    util.run("systemctl start stackdriver-agent google-fluentd")


def setup_munge():
    """ Overwrite munge service file and setup munge """

    munge_service_patch = Path('/usr/lib/systemd/system/munge.service')
    munge_service_patch.write_text("""
[Unit]
Description=MUNGE authentication service
Documentation=man:munged(8)
After=network.target
After=syslog.target

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
    util.run('create-munge-key -f')
    util.run("systemctl start munge")


def install_slurm():
    """ Compile and install slurm """

    src_path = dirs.slurm/'source'
    src_path.mkdir(parents=True, exist_ok=True)

    with cd(src_path):
        use_version = ''
        if (cfg.slurm_version[0:2] == 'b:'):
            GIT_URL = 'https://github.com/SchedMD/slurm.git'
            use_version = cfg.slurm_version[2:]
            util.run(
                "git clone -b {0} {1} {0}".format(use_version, GIT_URL))
        else:
            tarfile = 'slurm-{}.tar.bz2'.format(cfg.slurm_version)
            slurm_url = 'https://download.schedmd.com/slurm/' + tarfile
            urllib.request.urlretrieve(slurm_url, src_path/tarfile)

            use_version = util.run(f"tar -xvjf {tarfile}", check=True,
                                   get_stdout=True).stdout.splitlines()[0][:-1]
    src_path = src_path/use_version
    build_dir = dirs.slurm/'build'
    build_dir.mkdir(parents=True, exist_ok=True)

    with cd(build_dir):
        util.run(f"{src_path}/configure --prefix={dirs.install} --sysconfdir={slurmdirs.etc}")
        util.run("make -j install", stdout=DEVNULL)
    with cd(build_dir/'contribs'):
        util.run("make -j install", stdout=DEVNULL)

    for p in slurmdirs.values():
        p.mkdir(parents=True, exist_ok=True)
        shutil.chown(p, user='slurm', group='slurm')


def install_slurm_tmpfile():
    """ Add tmpfile entry for slurm """

    Path('/etc/tmpfiles.d/slurm.conf').write_text(
        f"\nd {slurmdirs.run} 0755 slurm slurm -")


def install_controller_service_scripts():
    """ Install slurmctld and slurmdbd service scripts """

    # slurmctld.service
    ctld_service = Path('/usr/lib/systemd/system/slurmctld.service')
    ctld_service.write_text(f"""
[Unit]
Description=Slurm controller daemon
After=network.target munge.service
ConditionPathExists={slurmdirs.etc}/slurm.conf

[Service]
Type=forking
EnvironmentFile=-/etc/sysconfig/slurmctld
ExecStart={dirs.install}/sbin/slurmctld $SLURMCTLD_OPTIONS
ExecReload=/bin/kill -HUP $MAINPID
PIDFile=/var/run/slurm/slurmctld.pid

[Install]
WantedBy=multi-user.target
""")

    ctld_service.chmod(0o644)

    # slurmdbd.service
    dbd_service = Path('/usr/lib/systemd/system/slurmdbd.service')
    dbd_service.write_text(f"""
[Unit]
Description=Slurm DBD accounting daemon
After=network.target munge.service
ConditionPathExists={slurmdirs.etc}/slurmdbd.conf

[Service]
Type=forking
EnvironmentFile=-/etc/sysconfig/slurmdbd
ExecStart={dirs.install}/sbin/slurmdbd $SLURMDBD_OPTIONS
ExecReload=/bin/kill -HUP $MAINPID
PIDFile=/var/run/slurm/slurmdbd.pid

[Install]
WantedBy=multi-user.target
""")

    dbd_service.chmod(0o644)


def install_compute_service_scripts():
    """ Install slurmd service file """

    # slurmd.service
    slurmd_service = Path('/usr/lib/systemd/system/slurmd.service')
    slurmd_service.write_text(f"""
[Unit]
Description=Slurm node daemon
After=network.target munge.service home.mount apps.mount etc-munge.mount
ConditionPathExists={slurmdirs.etc}/slurm.conf

[Service]
Type=forking
EnvironmentFile=-/etc/sysconfig/slurmd
ExecStart={dirs.install}/sbin/slurmd $SLURMD_OPTIONS
ExecReload=/bin/kill -HUP $MAINPID
PIDFile=/var/run/slurm/slurmd.pid
KillMode=process
LimitNOFILE=51200
LimitMEMLOCK=infinity
LimitSTACK=infinity

[Install]
WantedBy=multi-user.target
""")

    slurmd_service.chmod(0o644)


def setup_bash_profile():
    """ Add slurm and cuda to bash profile """

    Path('/etc/profile.d/slurm.sh').write_text(f"""
S_PATH={dirs.install}
PATH=$PATH:$S_PATH/bin:$S_PATH/sbin
""")

    Path('/etc/profile.d/cuda.sh').write_text("""
CUDA_PATH=/usr/local/cuda
PATH=$CUDA_PATH/bin${PATH:+:${PATH}}
LD_LIBRARY_PATH=$CUDA_PATH/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
""")


def setup_logrotate():
    """ configure logrotate for power scripts and slurm logs """
    Path('/etc/logrotate.d/slurm').write_text("""
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


# Tune the NFS server to support many mounts
def setup_nfs_threads():

    nfsd_conf = Path('/etc/sysconfig/nfs')
    if not nfsd_conf.exists():
        nfsd_conf = Path('/etc/default/nfs-kernel-server')
    with nfsd_conf.open('a') as f:
        f.write("""
# Added by Google
RPCNFSDCOUNT=256
""")


def setup_selinux():
    """ Make sure selinux is not enabled """
    if cfg.os_name in ('centos7', 'centos8'):
        util.run('setenforce 0')
        Path('/etc/selinux/config').write_text("""
SELINUX=permissive
SELINUXTYPE=targeted
""")


def install_ompi():
    """ compile and install OMPI """

    ompi_git = "https://github.com/open-mpi/ompi.git"
    ompi_path = dirs.apps/'ompi'/cfg.ompi_version/'src'
    ompi_path.mkdir(parents=True, exist_ok=True)
    util.run(f"git clone -b {cfg.ompi_version} {ompi_git} {ompi_path}")
    with cd(ompi_path):
        util.run("./autogen.pl", stdout=DEVNULL)

    build_path = ompi_path/'build'
    build_path.mkdir(parents=True, exist_ok=True)
    with cd(build_path):
        util.run(
            f"../configure --prefix={dirs.apps}/ompi/{cfg.ompi_version} "
            f"--with-pmi={dirs.apps}/slurm/current --with-libevent=/usr "
            "--with-hwloc=/usr", stdout=DEVNULL)
        util.run("make -j install", stdout=DEVNULL)


def remove_metadata():
    """ Remove metadata from instance """

    cmd = "gcloud compute instances remove-metadata"
    meta_keys = "startup-script,setup-script,util-script,fluentd-conf"

    util.run(f"{cmd} {cfg.hostname} --zone={cfg.zone} --keys={meta_keys}")
    util.run("systemctl enable tmp.mount")


def stop_instance():
    util.run(f"gcloud compute instances stop {cfg.hostname} --zone {cfg.zone} --quiet")


def main():

    setup_selinux()

    start_motd()

    add_slurm_user()
    install_packages()
    setup_munge()
    setup_bash_profile()
    setup_modules()

    install_slurm()
    #install_ompi()

    install_controller_service_scripts()
    install_compute_service_scripts()

    setup_nfs_threads()

    install_slurm_tmpfile()
    
    setup_logrotate()

    remove_metadata()
    end_motd()
    stop_instance()


if __name__ == '__main__':
    main()
