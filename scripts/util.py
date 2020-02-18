#!/usr/bin/env python3
# Copyright 2019 SchedMD LLC.
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
import logging.config
import os
import shlex
import subprocess
import sys
import time
from pathlib import Path
from contextlib import contextmanager
from collections import OrderedDict

import requests
import yaml


log = logging.getLogger(__name__)


def config_root_logger(level='DEBUG', util_level=None, file=None):
    if not util_level:
        util_level = level
    handler = 'file_handler' if file else 'stdout_handler'
    config = {
        'version': 1,
        'disable_existing_loggers': True,
        'formatters': {
            'standard': {
                'format': '',
            },
            'stamp': {
                'format': '%(asctime)s %(name)s %(levelname)s: %(message)s',
            },
        },
        'handlers': {
            'stdout_handler': {
                'level': 'DEBUG',
                'formatter': 'standard',
                'class': 'logging.StreamHandler',
                'stream': sys.stdout,
            },
        },
        'loggers': {
            '': {
                'handlers': [handler],
                'level': level,
            },
            __name__: {  # enable util.py logging
                'level': util_level,
            }
        },
    }
    if file:
        config['handlers']['file_handler'] = {
            'level': 'DEBUG',
            'formatter': 'stamp',
            'class': 'logging.handlers.WatchedFileHandler',
            'filename': file,
        }
    logging.config.dictConfig(config)


def get_metadata(path):
    """ Get metadata relative to metadata/computeMetadata/v1/instance/ """
    URL = 'http://metadata.google.internal/computeMetadata/v1/instance/'
    HEADERS = {'Metadata-Flavor': 'Google'}
    full_path = URL + path
    try:
        resp = requests.get(full_path, headers=HEADERS)
        resp.raise_for_status()
    except requests.exceptions.RequestException:
        log.exception(f"Error while getting metadata from {full_path}")
        return None
    return resp.text


def run(cmd, wait=0, quiet=False, get_stdout=False,
        shell=False, universal_newlines=True, **kwargs):
    """ run in subprocess. Optional wait after return. """
    if not quiet:
        log.debug(f"run: {cmd}")
    if get_stdout:
        kwargs['stdout'] = subprocess.PIPE

    args = cmd if shell else shlex.split(cmd)
    ret = subprocess.run(args, shell=shell,
                         universal_newlines=universal_newlines,
                         **kwargs)
    if wait:
        time.sleep(wait)
    return ret


def spawn(cmd, quiet=False, shell=False, **kwargs):
    """ nonblocking spawn of subprocess """
    if not quiet:
        log.debug(f"spawn: {cmd}")
    args = cmd if shell else shlex.split(cmd)
    return subprocess.Popen(args, shell=shell, **kwargs)


def get_pid(node_name):
    """Convert <prefix>-<pid>-<nid>"""

    return int(node_name.split('-')[-2])


@contextmanager
def cd(path):
    """ Change working directory for context """
    prev = Path.cwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(prev)


def static_vars(**kwargs):
    """
    Add variables to the function namespace.
    @static_vars(var=init): var must be referenced func.var
    """
    def decorate(func):
        for k in kwargs:
            setattr(func, k, kwargs[k])
        return func
    return decorate


class Config(OrderedDict):
    """ Loads config from yaml and holds values in nested namespaces """

    TYPES = set(('compute', 'login', 'controller'))
    # PROPERTIES defines which properties in slurm.jinja.schema are included
    #   in the config file. SAVED_PROPS are saved to file via save_config.
    SAVED_PROPS = ('project',
                   'zone',
                   'region',
                   'slurm_version',
                   'cluster_name',
                   'external_compute_ips',
                   'cluster_subnet',
                   'vpc_subnet',
                   'shared_vpc_host_proj',
                   'compute_node_prefix',
                   'compute_node_service_account',
                   'compute_node_scopes',
                   'slurm_cmd_path',
                   'log_dir',
                   'google_app_cred_path',
                   'partitions',
                   )
    PROPERTIES = (*SAVED_PROPS,
                  'munge_key',
                  'default_account',
                  'default_users',
                  'external_compute_ips',
                  'nfs_home_server',
                  'nfs_home_dir',
                  'nfs_apps_server',
                  'nfs_apps_dir',
                  'ompi_version',
                  'controller_secondary_disk',
                  'suspend_time',
                  'network_storage',
                  'login_network_storage',
                  'login_node_count',
                  'cloudsql',
                  )

    def __init__(self, *args, **kwargs):
        def from_nested(value):
            """ If value is dict, convert to Config. Also recurse lists. """
            if isinstance(value, dict):
                return Config({k: from_nested(v) for k, v in value.items()})
            elif isinstance(value, list):
                return [from_nested(v) for v in value]
            else:
                return value

        super(Config, self).__init__(*args, **kwargs)
        self.__dict__ = self  # all properties are member attributes

        # Convert nested dicts to Configs
        for k, v in self.items():
            self[k] = from_nested(v)

    @classmethod
    def new_config(cls, properties):
        # If k is ever not found, None will be inserted as the value
        return cls({k: properties.setdefault(k, None) for k in cls.PROPERTIES})

    @classmethod
    def load_config(cls, path):
        config = yaml.safe_load(Path(path).read_text())
        return cls(config)

    def save_config(self, path):
        save_dict = {k: self[k] for k in self.SAVED_PROPS}
        Path(path).write_text(yaml.dump(save_dict, Dumper=self.Dumper))

    @property
    def instance_type(self):
        try:
            return self._instance_type
        except AttributeError:
            # get tags, intersect with possible types, get the first or none
            tags = yaml.safe_load(get_metadata('tags'))
            # TODO what to default to if no match found.
            self._instance_type = next(iter(set(tags) & self.TYPES), None)
            return self._instance_type

    class Dumper(yaml.SafeDumper):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            self.add_representer(Config, self.represent_config)

        @staticmethod
        def represent_config(dumper, data):
            return dumper.represent_mapping('tag:yaml.org,2002:map',
                                            data.items())
