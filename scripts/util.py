#!/usr/bin/env python3

import logging
import logging.config
import os
import shlex
import subprocess
import sys
import time
from pathlib import Path
from contextlib import contextmanager

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
    except requests.exceptions.RequestException as e:
        print(f"Error while getting metadata from {full_path}")
        print(e)
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


class Config:

    TYPES = set(('compute', 'login', 'controller'))
    # PROPERTIES defines which properties in slurm.jinja.schema are included
    #   in the config file. A tuple indicates a change of dict key.
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
                  )

    def __init__(self, properties):
        # Add all properties to object namespace
        for k, v in properties.items():
            setattr(self, k, v)

    @classmethod
    def new_config(cls, properties):
        # If k is ever not found, None will be inserted as the value
        return cls({k: properties.setdefault(k, None) for k in cls.PROPERTIES})

    @classmethod
    def load_config(cls, path):
        config = yaml.safe_load(Path(path).read_text())
        return cls(config)

    def save_config(self, path):
        with Path(path).open('w') as f:
            yaml.safe_dump({k: getattr(self, k) for k in self.SAVED_PROPS}, f)

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
