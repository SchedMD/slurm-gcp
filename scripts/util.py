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
import socket
import time
from itertools import chain, compress
from pathlib import Path
from contextlib import contextmanager
from collections import OrderedDict
import googleapiclient.discovery

import requests
import yaml


log = logging.getLogger(__name__)


def config_root_logger(level='DEBUG', util_level=None,
                       stdout=True, logfile=None):
    if not util_level:
        util_level = level
    handlers = list(compress(('stdout_handler', 'file_handler'),
                             (stdout, logfile)))

    config = {
        'version': 1,
        'disable_existing_loggers': True,
        'formatters': {
            'standard': {
                'format': '',
            },
            'stamp': {
                'format': '%(asctime)s %(process)s %(thread)s %(name)s %(levelname)s: %(message)s',
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
            __name__: {  # enable util.py logging
                'level': util_level,
            },
        },
        'root': {
            'handlers': handlers,
            'level': level,
        }
    }
    if logfile:
        config['handlers']['file_handler'] = {
            'level': 'DEBUG',
            'formatter': 'stamp',
            'class': 'logging.handlers.WatchedFileHandler',
            'filename': logfile,
        }
    logging.config.dictConfig(config)


def handle_exception(exc_type, exc_value, exc_trace):
    if not issubclass(exc_type, KeyboardInterrupt):
        log.exception("Fatal exception",
                      exc_info=(exc_type, exc_value, exc_trace))
    sys.__excepthook__(exc_type, exc_value, exc_trace)


def get_metadata(path):
    """ Get metadata relative to metadata/computeMetadata/v1/instance/ """
    URL = 'http://metadata.google.internal/computeMetadata/v1/instance/'
    HEADERS = {'Metadata-Flavor': 'Google'}
    full_path = URL + path
    try:
        resp = requests.get(full_path, headers=HEADERS)
        resp.raise_for_status()
    except requests.exceptions.RequestException:
        log.error(f"Error while getting metadata from {full_path}")
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

    return '-'.join(node_name.split('-')[:-1])


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


class cached_property:
    """
    Descriptor for creating a property that is computed once and cached
    """
    def __init__(self, factory):
        self._attr_name = factory.__name__
        self._factory = factory

    def __get__(self, instance, owner=None):
        if instance is None:  # only if invoked from class
            return self
        attr = self._factory(instance)
        setattr(instance, self._attr_name, attr)
        return attr


class NSDict(OrderedDict):
    """ Simple nested dict namespace """

    def __init__(self, *args, **kwargs):
        def from_nested(value):
            """ If value is dict, convert to NSDict. Also recurse lists. """
            if isinstance(value, dict):
                return type(self)({k: from_nested(v) for k, v in value.items()})
            elif isinstance(value, list):
                return [from_nested(v) for v in value]
            else:
                return value

        super(NSDict, self).__init__(*args, **kwargs)
        self.__dict__ = self  # all properties are member attributes

        # Convert nested elements
        for k, v in self.items():
            self[k] = from_nested(v)


class Config(NSDict):
    """ Loads config from yaml and holds values in nested namespaces """

    TYPES = set(('compute', 'login', 'controller'))
    # PROPERTIES defines which properties in slurm.jinja.schema are included
    #   in the config file. SAVED_PROPS are saved to file via save_config.
    SAVED_PROPS = ('project',
                   'zone',
                   'cluster_name',
                   'external_compute_ips',
                   'shared_vpc_host_project',
                   'compute_node_service_account',
                   'compute_node_scopes',
                   'slurm_cmd_path',
                   'log_dir',
                   'google_app_cred_path',
                   'update_node_addrs',
                   'network_storage',
                   'login_network_storage',
                   'instance_defs',
                   )
    PROPERTIES = (*SAVED_PROPS,
                  'munge_key',
                  'jwt_key',
                  'external_compute_ips',
                  'controller_secondary_disk',
                  'suspend_time',
                  'login_node_count',
                  'cloudsql',
                  'partitions',
                  )

    def __init__(self, *args, **kwargs):
        super(Config, self).__init__(*args, **kwargs)

    @classmethod
    def new_config(cls, properties):
        # If k is ever not found, None will be inserted as the value
        cfg = cls({k: properties.setdefault(k, None) for k in cls.PROPERTIES})
        if cfg.partitions:
            cfg['instance_defs'] = Config({
                f'{cfg.cluster_name}-compute-{pid}': part
                for pid, part in enumerate(cfg.partitions)
            })

        for netstore in (*cfg.network_storage, *(cfg.login_network_storage or []),
                         *chain(*(p.network_storage for p in (cfg.partitions or [])))):
            if netstore.server_ip == '$controller':
                netstore.server_ip = cfg.cluster_name + '-controller'
        return cfg

    @classmethod
    def load_config(cls, path):
        config = yaml.safe_load(Path(path).read_text())
        return cls(config)

    def save_config(self, path):
        save_dict = Config([(k, self[k]) for k in self.SAVED_PROPS])
        if save_dict.instance_defs:
            for instance_type in save_dict.instance_defs.values():
                instance_type.pop('max_node_count', 0)
                instance_type.pop('name', 0)
                instance_type.pop('static_node_count', 0)
        Path(path).write_text(yaml.dump(save_dict, Dumper=Dumper))

    @cached_property
    def instance_type(self):
        # get tags, intersect with possible types, get the first or none
        tags = yaml.safe_load(get_metadata('tags'))
        # TODO what to default to if no match found.
        return next(iter(set(tags) & self.TYPES), None)

    @cached_property
    def hostname(self):
        return socket.gethostname()

    @property
    def region(self):
        if self.zone:
            parts = self.zone.split('-')
            if len(parts) > 2:
                return '-'.join(parts[:-1])
            else:
                return self.zone
        return None

    @property
    def exclusive(self):
        return bool(self.get('exclusive', False) or self.enable_placement)

    def __getattr__(self, item):
        """ only called if item is not found in self """
        return None


class Dumper(yaml.SafeDumper):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.add_representer(Config, self.represent_nsdict)
        self.add_representer(NSDict, self.represent_nsdict)
        self.add_multi_representer(Path, self.represent_path)

    @staticmethod
    def represent_nsdict(dumper, data):
        return dumper.represent_mapping('tag:yaml.org,2002:map',
                                        data.items())

    @staticmethod
    def represent_path(dumper, path):
        return dumper.represent_scalar('tag:yaml.org,2002:str',
                                       str(path))


def ensure_execute(operation):
    """ Handle rate limits and socket time outs """

    retry = 0
    sleep = 1
    max_sleep = 60
    while True:
        try:
            return operation.execute()

        except googleapiclient.errors.HttpError as e:
            if "Rate Limit Exceeded" in str(e):
                retry += 1
                sleep = min(sleep*2, max_sleep)
                log.error(f"retry:{retry} sleep:{sleep} '{e}'")
                time.sleep(sleep)
                continue
            raise

        except socket.timeout as e:
            # socket timed out, try again
            log.debug(e)

        except Exception as e:
            log.error(e, exc_info=True)
            raise

        break


def wait_for_operation(compute, project, operation):
    print('Waiting for operation to finish...')
    while True:
        if 'zone' in operation:
            operation = compute.zoneOperations().wait(
                project=project,
                zone=operation['zone'].split('/')[-1],
                operation=operation['name'])
        elif 'region' in operation:
            operation = compute.regionOperations().wait(
                project=project,
                region=operation['region'].split('/')[-1],
                operation=operation['name'])
        else:
            operation = compute.globalOperations().wait(
                project=project,
                operation=operation['name'])

        result = ensure_execute(operation)
        if result['status'] == 'DONE':
            print("done.")
            return result


def get_group_operations(compute, project, operation):
    """ get list of operations associated with group id """

    group_id = operation['operationGroupId']
    if 'zone' in operation:
        operation = compute.zoneOperations().list(
            project=project,
            zone=operation['zone'].split('/')[-1],
            filter=f"operationGroupId={group_id}")
    elif 'region' in operation:
        operation = compute.regionOperations().list(
            project=project,
            region=operation['region'].split('/')[-1],
            filter=f"operationGroupId={group_id}")
    else:
        operation = compute.globalOperations().list(
            project=project,
            filter=f"operationGroupId={group_id}")

    return ensure_execute(operation)


def get_regional_instances(compute, project, def_list):
    """ Get instances that exist in regional capacity instance defs """

    fields = 'items.zones.instances(name,zone,status),nextPageToken'
    regional_instances = {}

    region_filter = ' OR '.join(f'(name={pid}-*)' for pid, d in
                                def_list.items() if d.regional_capacity)
    if region_filter:
        page_token = ""
        while True:
            resp = ensure_execute(
                compute.instances().aggregatedList(
                    project=project, filter=region_filter, fields=fields,
                    pageToken=page_token))
            if not resp:
                break
            for zone, zone_value in resp['items'].items():
                if 'instances' in zone_value:
                    regional_instances.update(
                        {instance['name']: instance
                         for instance in zone_value['instances']}
                    )
            if "nextPageToken" in resp:
                page_token = resp['nextPageToken']
                continue
            break

    return regional_instances
