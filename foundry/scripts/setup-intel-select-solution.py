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
    
    
def stop_instance():
    util.run(f"gcloud compute instances stop {cfg.hostname} --zone {cfg.zone} --quiet")
    
    
def main():
    # Build image upon the slurm-hpc image.
    # Only need to stop the instances. 
    stop_instance()
        

if __name__ == '__main__':
    main()
