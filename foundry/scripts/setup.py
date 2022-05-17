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
import shlex
import shutil
import socket
import sys
import time
import urllib.request
from functools import partialmethod
from pathlib import Path
from subprocess import DEVNULL
from concurrent.futures import ThreadPoolExecutor

import googleapiclient.discovery
import requests
import yaml


Path.mkdirp = partialmethod(Path.mkdir, parents=True, exist_ok=True)
TMPDIR = Path('/tmp')
SCRIPTSDIR = Path('/root/image-scripts')
SCRIPTSDIR.mkdirp()
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
cached_property = util.cached_property

util.config_root_logger(file=str(SCRIPTSDIR/'setup.log'))
log = logging.getLogger(Path(__file__).name)


class Config(util.NSDict):
    """ Loads config from yaml and holds values in nested namespaces """

    def __init__(self, *args, **kwargs):
        super(Config, self).__init__(*args, **kwargs)

    @staticmethod
    def _prop_from_meta(item):
        return yaml.safe_load(util.get_metadata(f'attributes/{item}'))

    @cached_property
    def slurm_version(self):
        # match 'b:<branch_name>' or eg. '20.02-latest', '20.02.0', '20.02.0-1'
        #patt = re.compile(r'(b:\S+)|((\d+[\.-])+\w+)')
        return self._prop_from_meta('slurm_version')

    @cached_property
    def libjwt_version(self):
        return self._prop_from_meta('libjwt_version')

    @cached_property
    def ompi_version(self):
        return self._prop_from_meta('ompi_version')

    @cached_property
    def zone(self):
        return util.get_metadata('zone')

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
        yum = "yum"
        apt = "apt-get"
        return {
            'centos7': yum,
            'centos8': yum,
            'debian9': apt,
            'debian10': apt,
            'ubuntu2004': apt,
        }[self.os_name]

    def update(self):
        if self.os_name in ('centos7', 'centos8'):
            return
        util.run(f"{cfg.pacman} update")

    def __getattr__(self, item):
        """ only called if item is not found in self """
        return None


# get setup config from metadata
#config_yaml = yaml.safe_load(util.get_metadata('attributes/config'))
#if not util.get_metadata('attributes/terraform'):
#    config_yaml = yaml.safe_load(config_yaml)
cfg = Config()

dirs = util.NSDict({n: Path(p) for n, p in dict.items({
    'slurm': '/slurm',
    'build': '/tmp/build',
    'install': '/usr/local',
    'apps': '/apps',
    'munge': '/etc/munge',
    'modulefiles': '/apps/modulefiles',
})})

for p in dirs.values():
    p.mkdirp()

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


def create_users():
    """ Create user slurm """
    util.run("groupadd munge -g 980")
    util.run("useradd -m -c MungeUser -d /var/run/munge -r munge -u 980 -g 980")

    util.run("groupadd slurm -g 981")
    util.run("useradd -m -c SlurmUser -d /var/lib/slurm -r slurm -u 981 -g 981")

    util.run("groupadd slurmrestd -g 982")
    util.run("useradd -m -c Slurmrestd -d /var/lib/slurmrestd -r slurmrestd -u 982 -g 982")


def setup_modules():
    """ Add /apps/modulefiles as environment module dir """

    # for Debian 10
    modulepaths = Path('/etc/lmod/modulespath')
    if modulepaths.exists():
        paths = [path for path in modulepaths.read_text().splitlines()
                 if not path.startswith('#')]
        if str(dirs.modulefiles) not in paths:
            with modulepaths.open('a') as f:
                f.write(f"\n{dirs.modulefiles}")

    # for CentOS 7
    modulespath = Path('/usr/share/lmod/lmod/init/.modulespath')
    modulespath.write_text(f"""
{dirs.modulefiles}
""")


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

    slurmlog_config = util.get_metadata('attributes/ops-agents-yaml')
    if slurmlog_config:
        conf_file = Path('/etc/google-cloud-ops-agent/config.yaml')
        conf_file.write_text(slurmlog_config)


def install_lustre():
    """ Install lustre client drivers """
    lustre_tmp = Path('/root/lustre-pkg')
    lustre_tmp.mkdirp()

    if cfg.os_name in ('centos7', 'centos8', 'rhel7', 'rhel8'):
        rpm_url = 'https://downloads.whamcloud.com/public/lustre/latest-release/el7/client/RPMS/x86_64/'
        srpm_url = 'https://downloads.whamcloud.com/public/lustre/latest-release/el7/client/SRPMS/'

        util.run('yum update -y')

        rpmlist = ','.join(('kmod-lustre-client-2*.rpm', 'lustre-client-2*.rpm'))
        util.run(
            f"wget -nv -r -l1 -np -nd -A '{rpmlist}' '{rpm_url}' -P {lustre_tmp}")
        util.run(
            f"find {lustre_tmp} -name '*.rpm' -execdir rpm -ivh {{}} ';'")

        srpm = 'lustre-client-dkms-2*.src.rpm'
        util.run(f"wget -nv -r -l1 -np -nd -A {srpm} {srpm_url} -P {lustre_tmp}")
        srpm = next(lustre_tmp.glob(srpm))
        with cd(lustre_tmp):
            util.run(f"rpm2cpio {srpm} | cpio -idmv", shell=True)
        srctar = next(lustre_tmp.glob('lustre-2*.tar.gz'))
        util.run(f"tar xf {srctar} -C /usr/src")

        util.run(f"rm -rf {lustre_tmp}")
        util.run("modprobe lustre")
    elif cfg.os_name in ('debian10', 'ubuntu2004'):
        deb_url = 'https://downloads.whamcloud.com/public/lustre/latest-release/ubuntu1804/client/'
        deblist = ','.join(('lustre-client-*_amd64.deb', 'lustre-source*.deb'))
        util.run(f"wget -nv -r -l1 -np -nd -A {deblist} {deb_url} -P {lustre_tmp}")
        for deb in lustre_tmp.glob('*.deb'):
            util.run(f"dpkg -i {deb}")
        util.run("apt-get install -f -y")


def install_gcsfuse():
    """ Instal gcsfuse driver """
    if cfg.os_name in ('centos7', 'centos8', 'rhel7', 'rhel8'):
        Path('/etc/yum.repos.d/gcsfuse.repo').write_text("""
[gcsfuse]
name=gcsfuse (packages.cloud.google.com)
baseurl=https://packages.cloud.google.com/yum/repos/gcsfuse-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
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
    nvidia_version = '460.106.00'
    nvidia_run = TMPDIR/f'NVIDIA-Linux-x86_64-{nvidia_version}.run'
    nvidia_url = f'https://us.download.nvidia.com/tesla/{nvidia_version}/{nvidia_run.name}'
    util.run(f"wget -nv {nvidia_url} -O {nvidia_run}")
    util.run(f"bash {nvidia_run} --silent --dkms")

    cuda_version = '11.2.2'
    cuda_driver_version = '460.32.03'
    cuda_run = TMPDIR/f'cuda_{cuda_version}_{cuda_driver_version}_linux.run'
    cuda_url = f'https://developer.download.nvidia.com/compute/cuda/{cuda_version}/local_installers/{cuda_run.name}'
    cuda_samples_dir = Path('/usr/local/share/cuda/samples')
    util.run(f"wget -nv {cuda_url} -O {cuda_run}")
    util.run(f"bash {cuda_run} --silent --toolkit --samples --samplespath={cuda_samples_dir}")

    # delete run files to save space, but record the url
    (SCRIPTSDIR/'nvidia_url').write_text(nvidia_url)
    nvidia_run.unlink()
    (SCRIPTSDIR/'cuda_url').write_text(cuda_url)
    cuda_run.unlink()

    # add cuda to path and LD
    Path('/etc/profile.d/cuda.sh').write_text("""
CUDA_PATH=/usr/local/cuda
PATH=$CUDA_PATH/bin${PATH:+:${PATH}}
LD_LIBRARY_PATH=$CUDA_PATH/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
""")

    # compile cuda samples
    samples_dir = next(cuda_samples_dir.glob('NVIDIA_CUDA-*'))
    with cd(samples_dir):
        cuda_install = Path('/usr/local/cuda')
        env = os.environ.copy()
        path = env.get('PATH')
        ld_path = env.get('LD_LIBRARY_PATH', None)
        env['PATH'] = f"{cuda_install}/bin:{path}"
        env['LD_LIBRARY_PATH'] = ':'.join(
            e for e in [f'{cuda_install}/lib64', ld_path] if e)
        util.run("make", stdout=DEVNULL, env=env)


def install_libjwt():

    JWT_PREFIX = dirs.install
    src_path = dirs.install/'src/libjwt'
    src_path.mkdirp()

    GIT_URL = 'https://github.com/benmcollins/libjwt.git'
    util.run(
        "git clone --single-branch --depth 1 -b {0} {1} {2}".format(cfg.libjwt_version, GIT_URL, src_path))

    with cd(src_path):
        util.run("autoreconf -if")
    build_path = dirs.build/'libjwt'
    build_path.mkdirp()

    with cd(build_path):
        util.run(f"{src_path}/configure --prefix={JWT_PREFIX} --sysconfdir={JWT_PREFIX}/etc",
                 stdout=DEVNULL)
        util.run("make -j install", stdout=DEVNULL)
    util.run("ldconfig")


def set_gcloud_version():
    if cfg.os_name.startswith('centos'):
        gcloud_version = '365.0.1-1'
        util.run(f"yum downgrade -y google-cloud-sdk-{gcloud_version}")
        util.run(f"yum versionlock add google-cloud-sdk-{gcloud_version}")


def install_dependencies():
    """ Install all dependencies """

    Path('/etc/ld.so.conf.d/usr-local.conf').write_text("""
/usr/local/lib
/usr/local/lib64
""")
    if cfg.os_name in ('centos7', 'centos8'):
        util.run(f"{cfg.pacman} -y groupinstall 'Development Tools'")
    packages = util.get_metadata('attributes/packages').splitlines()
    util.run(f"{cfg.pacman} install -y {' '.join(packages)}", shell=True,
             env=dict(os.environ, DEBIAN_FRONTEND='noninteractive'))
    install_libjwt()
    set_gcloud_version()


def install_apps():
    """ Install all core applications using system package manager """

    install_lustre()
    install_gcsfuse()
    install_cuda()

    script = SCRIPTSDIR/'add-google-cloud-ops-agent-repo.sh'
    url = f'https://dl.google.com/cloudagents/{script.name}'
    urllib.request.urlretrieve(url, script)
    util.run(f"bash {script} --also-install")
    install_slurmlog_conf()


def install_compiled_apps():
    """ Compile and install Slurm and Openmpi """
    install_slurm()
    install_ompi()


def setup_munge():
    """ Overwrite munge service file and setup munge """

    munge_service_patch = Path('/usr/lib/systemd/system/munge.service')
    munge_service_patch.write_text("""
[Unit]
Description=MUNGE authentication service
Documentation=man:munged(8)
After=network.target remote-fs.target
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


def install_slurm():
    """ Compile and install slurm """

    src_path = dirs.install/'src'
    src_path.mkdirp()

    with cd(src_path):
        use_version = ''
        if cfg.slurm_version.startswith('b:'):
            GIT_URL = 'https://github.com/SchedMD/slurm.git'
            use_version = cfg.slurm_version[2:]
            util.run(
                "git clone --single-branch --depth 1 -b {0} {1} {0}".format(use_version, GIT_URL))
        else:
            tarfile = 'slurm-{}.tar.bz2'.format(cfg.slurm_version)
            slurm_url = 'https://download.schedmd.com/slurm/' + tarfile
            urllib.request.urlretrieve(slurm_url, src_path/tarfile)

            use_version = util.run(f"tar -xvjf {tarfile}", check=True,
                                   get_stdout=True).stdout.splitlines()[0][:-1]
    src_path = src_path/use_version
    build_dir = dirs.build/'slurm'
    build_dir.mkdirp()

    with cd(build_dir):
        util.run(f"{src_path}/configure --prefix={dirs.install} --sysconfdir={slurmdirs.etc} --with-jwt={dirs.install}")
        util.run("make -j install", stdout=DEVNULL)
    with cd(build_dir/'contribs'):
        util.run("make -j install", stdout=DEVNULL)

    for p in slurmdirs.values():
        p.mkdirp()
        shutil.chown(p, user='slurm', group='slurm')
    util.run("ldconfig")


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
Requires=munge.service
ConditionPathExists={slurmdirs.etc}/slurm.conf

[Service]
Type=simple
EnvironmentFile=-/etc/sysconfig/slurmctld
ExecStart={dirs.install}/sbin/slurmctld -D $SLURMCTLD_OPTIONS
ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536
TasksMax=infinity
WorkingDirectory={slurmdirs.log}

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
Requires=munge.service
ConditionPathExists={slurmdirs.etc}/slurmdbd.conf

[Service]
Type=simple
EnvironmentFile=-/etc/sysconfig/slurmdbd
ExecStart={dirs.install}/sbin/slurmdbd -D $SLURMDBD_OPTIONS
ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536
TasksMax=infinity

[Install]
WantedBy=multi-user.target
""")

    dbd_service.chmod(0o644)

    # slurmrestd.service
    slurmrestd_service = Path('/usr/lib/systemd/system/slurmrestd.service')
    with slurmrestd_service.open('w') as f:
        f.write(f"""
[Unit]
Description=Slurm REST daemon
After=network.target munge.service slurmctld.service
Requires=munge.service
ConditionPathExists={slurmdirs.etc}/slurm.conf

[Service]
Type=simple
User=slurmrestd
Group=slurmrestd
EnvironmentFile=-/etc/sysconfig/slurmrestd
Environment="SLURM_JWT=daemon"
Environment="SLURMRESTD_BINDS=localhost:8383 0.0.0.0:6842 :::8642"
ExecStart={dirs.install}/sbin/slurmrestd $SLURMRESTD_OPTIONS $SLURMRESTD_BINDS
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
""")

    slurmrestd_service.chmod(0o644)


def install_compute_service_scripts():
    """ Install slurmd service file """

    # slurmd.service
    slurmd_service = Path('/usr/lib/systemd/system/slurmd.service')
    slurmd_service.write_text(f"""
[Unit]
Description=Slurm node daemon
After=network.target munge.service
Requires=munge.service
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
        Path('/etc/selinux/config').write_text("""
SELINUX=disabled
SELINUXTYPE=targeted
""")


def setup_grub():
    if cfg.os_name == 'debian10':
        grubd = Path('/etc/default/grub.d')
        if grubd.exists():
            (grubd/'slurm_cgroup.cfg').write_text("""
GRUB_CMDLINE_LINUX="${GRUB_CMDLINE_LINUX} cgroup_enable=memory swapaccount=1"
""")
            util.run("update-grub")


def install_ompi():
    """ compile and install OMPI """

    ompi_git = "https://github.com/open-mpi/ompi.git"
    ompi_path = (dirs.apps/'ompi')/cfg.ompi_version
    ompi_path.mkdirp()

    ompi_src = ompi_path/'src'
    ompi_src.mkdirp()
    util.run(f"git clone --single-branch --depth 1 -b {cfg.ompi_version} {ompi_git} {ompi_src}")
    with cd(ompi_src):
        util.run("./autogen.pl", stdout=DEVNULL)

    ompi_build = dirs.build/'ompi'
    ompi_build.mkdirp()
    with cd(ompi_build):
        util.run(
            f"{ompi_src}/configure --prefix={ompi_path} "
            f"--with-pmi={dirs.install} --with-libevent=/usr "
            "--with-hwloc=/usr", stdout=DEVNULL)
        util.run("make -j install", stdout=DEVNULL)

    ompi_sym = ompi_path.parent/'openmpi'
    ompi_sym.symlink_to(ompi_path)
    ompi_modulepath = Path('/apps/modulefiles/openmpi')
    ompi_modulepath.mkdirp()
    (ompi_modulepath/f'{cfg.ompi_version}.lua').write_text(f"""
ompi_install="{ompi_path}"
prepend_path("PATH", ompi_install.."/bin")
prepend_path("LD_LIBRARY_PATH", ompi_install.."/lib")
prepend_path("MANPATH", ompi_install.."/share/man")
setenv("MPI_HOME", ompi_install)
setenv("MPI_BIN", ompi_install.."/bin")
setenv("MPI_SYSCONFIG", ompi_install.."/etc")
setenv("MPI_INCLUDE", ompi_install.."/include")
setenv("MPI_LIB", ompi_install.."/lib")
setenv("MPI_MAN", ompi_install.."/share/man")
""")


def run_custom_scripts():
    prefix = 'custom-'
    metadata = util.get_metadata('attributes/').split('\n')
    custom_scripts = [s for s in metadata if s.startswith(prefix)]

    custom_path = dirs.slurm/'custom-scripts'
    custom_path.mkdirp()
    for script in custom_scripts:
        name = script[len(prefix):]
        path = custom_path/name
        path.write_text(util.get_metadata(f'attributes/{script}'))
        path.chmod(0o755)

    for script in sorted(custom_path.glob('*')):
        util.run(str(script.resolve()))


def remove_metadata():
    """ Remove metadata from instance """

    cmd = "gcloud compute instances remove-metadata"
    meta_keys = "startup-script,setup-script,util-script,fluentd-conf"

    util.run(f"{cmd} {cfg.hostname} --zone={cfg.zone} --keys={meta_keys}")


def stop_instance():
    util.run(f"gcloud compute instances stop {cfg.hostname} --zone {cfg.zone} --quiet")


def main():

    # start tmpfs at /tmp now
    util.run("systemctl enable tmp.mount")
    util.run("systemctl start tmp.mount")

    setup_selinux()

    start_motd()

    create_users()
    install_dependencies()

    #with ThreadPoolExecutor() as exe:
    #    exe.submit(install_compiled_apps)
    #    exe.submit(install_apps)
    install_apps()
    install_compiled_apps()

    setup_munge()
    setup_bash_profile()
    setup_modules()
    setup_grub()

    install_controller_service_scripts()
    install_compute_service_scripts()

    setup_nfs_threads()

    install_slurm_tmpfile()
    run_custom_scripts()
    
    setup_logrotate()

    #util.run("touch /.google_hpc_firstrun")

    remove_metadata()
    end_motd()
    stop_instance()


if __name__ == '__main__':
    main()
