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
import re
import shlex
import socket
import subprocess
import sys
from collections import defaultdict, deque
from concurrent.futures import ThreadPoolExecutor, Future
from contextlib import contextmanager
from functools import lru_cache, cached_property
from itertools import chain, compress
from operator import itemgetter
from pathlib import Path
from threading import Lock
from time import sleep

import googleapiclient.discovery
import requests
import yaml
from addict import Dict as NSDict


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


ROOT_URL = 'http://metadata.google.internal/computeMetadata/v1'


def get_metadata(path, root=ROOT_URL):
    """ Get metadata relative to metadata/computeMetadata/v1 """
    HEADERS = {'Metadata-Flavor': 'Google'}
    url = f'{root}/{path}'
    try:
        resp = requests.get(url, headers=HEADERS)
        resp.raise_for_status()
        return resp.text
    except requests.exceptions.RequestException:
        log.error(f"Error while getting metadata from {url}")
        return None


def instance_metadata(path):
    """Get instance metadata"""
    return get_metadata(path, root=f"{ROOT_URL}/instance")


def run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=False,
        timeout=None, check=True, universal_newlines=True, **kwargs):
    """Wrapper for subprocess.run() with convenient defaults"""
    log.debug(f"run: {cmd}")
    args = cmd if shell else shlex.split(cmd)
    result = subprocess.run(args, stdout=stdout, stderr=stderr, shell=shell,
                            timeout=timeout, check=check,
                            universal_newlines=universal_newlines, **kwargs)
    return result


def spawn(cmd, quiet=False, shell=False, **kwargs):
    """ nonblocking spawn of subprocess """
    if not quiet:
        log.debug(f"spawn: {cmd}")
    args = cmd if shell else shlex.split(cmd)
    return subprocess.Popen(args, shell=shell, **kwargs)


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


class threadsafe_iterator:
    """ make any iterator or generator thread-safe """
    def __init__(self, iterator):
        self.iterator = iterator
        self.lock = Lock()

    def __iter__(self):
        return self

    def __next__(self):
        with self.lock:
            return self.iterator.__next__()


def threadsafe_generator(func):
    """ Decorator that applies threadsafe_iterator to a generator """
    def wrapper(*args, **kwargs):
        return threadsafe_iterator(func(*args, **kwargs))
    return wrapper


class SyncCompute:
    """
    Synchronized wrapper for compute api handle
    with SyncCompute() as compute:
        compute.instance().get(...)
    """
    def __init__(self):
        self._lock = Lock()
        self._compute = googleapiclient.discovery.build(
            'compute', 'v1', cache_discovery=False)

    @property
    def locked(self):
        return self._lock.locked()

    def lock(self):
        self._lock.acquire()

    def unlock(self):
        self._lock.release()

    def __enter__(self):
        # we lock in compute_pool generator to avoid 
        # very rare hypothetical race condition
        # if this class was used outside a compute pool, lock here
        if not self.locked:
            self.lock()
        return self._compute

    def __exit__(self, type, value, traceback):
        self.unlock()


@threadsafe_generator
def make_compute_pool(max_count=None, wait=1):
    """ maintains a pool of SyncCompute objects, only yielding them when they
    are not thread locked
    pool = make_compute_pool()
    with next(pool) as compute:
        compute.instances.get(...)
    """
    pool = deque(maxlen=max_count)
    while True:
        find_unlocked = (
            (c, i) for i, c in enumerate(pool, start=1) if not c.locked
        )
        compute, i = next(find_unlocked, (None, 0))
        if not compute:
            if max_count and len(pool) >= max_count:
                sleep(wait)
                continue
            compute = SyncCompute()
            pool.append(compute)
        pool.rotate(-i)  # optimization, move first i to the back
        compute.lock()
        yield compute


class Lookup:
    """ Wrapper class for cached data looked up from Google or derived from a
    Config
    """
    regex = r'(?P<name>[^\s\-]+)-(?P<template>\S+)-(?P<partition>[^\s\-]+)-(?P<index>\d+)'
    node_parts_regex = re.compile(regex)

    def __init__(self, cfg=None):
        self.compute_pool = make_compute_pool()
        self.cfg = cfg or Config()

    @cached_property
    def node_role(self):
        return instance_metadata('attributes/instance_type')

    @cached_property
    def project_metadata(self):
        return get_metadata(
            f'project/attributes/{self.cfg.cluster_name}-slurm-metadata'
        )

    @cached_property
    def hostname(self):
        return socket.gethostname()

    @property
    def exclusive(self):
        return bool(self.cfg.exclusive or self.cfg.enable_placement)

    def sync_compute(self):
        return next(self.compute_pool)

    @cached_property
    def template_nodes(self):
        template_nodes = defaultdict(list)
        with ThreadPoolExecutor() as exe:
            futures = {}
            for part, conf in self.cfg.partitions.items():
                for node in conf.nodes:
                    # shim in partition so template knows it for nodeline
                    node.partition = part
                    template_nodes[node.template].append(node)
                    f = exe.submit(self.template_details, node.template)
                    futures[f] = node
            # not strictly necessary, but store a reference to the template
            # details on each node just for fun
            for f, node in futures.items():
                node.template_details = f.result()
        return template_nodes

    @lru_cache(maxsize=None)
    def _node_parts(self, node_name):
        """ Get parts from node name """
        m = self.node_parts_regex.match(node_name)
        if not m:
            raise Exception(f"node name {node_name} is not valid")
        return NSDict(m.groupdict())

    def node_template(self, node_name):
        return self._node_parts(node_name).template

    def node_template_props(self, node_name):
        return self.template_props(self.node_template(node_name))
    
    def node_template_details(self, node_name):
        return self.template_props(self.node_template(node_name))
    
    def node_partition(self, node_name):
        return self._node_parts(node_name).partition

    def node_index(self, node_name):
        return self._node_parts(node_name).index

    def get_node_conf(self, node_name):
        parts = self._node_parts(node_name)
        try:
            node_conf = next(
                n for n in self.cfg.partitions[parts.partition].nodes
                if n.template == parts.template
            )
        except StopIteration:
            raise Exception(f"node name {node_name} not found among partitions nodes")
        return node_conf

    def template_details(self, template, project=None):
        template_props = self.template_props(template)
        if template_props.machine:
            return template_props

        template_props.machine_details = self.machine_type(
            template_props.machineType)
        md = template_props.machine_details
        machine = NSDict()

        # TODO how is smt passed?
        #machine['cpus'] = machine['guestCpus'] // (1 if part.image_hyperthreads else 2) or 1
        machine.cpus = md.guestCpus
        # Because the actual memory on the host will be different than
        # what is configured (e.g. kernel will take it). From
        # experiments, about 16 MB per GB are used (plus about 400 MB
        # buffer for the first couple of GB's. Using 30 MB to be safe.
        gb = md.memoryMb // 1024
        machine.memory = md.memoryMb - (400 + (30 * gb))

        machine.gpu_count = md.guestAccelerators.acceleratorCount or 0
        machine.gpu_type = md.guestAccelerators.acceleratorType or None

        template_props.machine = machine
        return template_props

    @lru_cache(maxsize=None)
    def template_props(self, template, project=None):
        if project is None:
            project = self.cfg.project

        tpl_filter = f'(name={self.cfg.cluster_name}-{template}-*)'
        with self.sync_compute() as compute:
            template_list = ensure_execute(
                compute.instanceTemplates().list(
                    project=project,
                    filter=tpl_filter)
            ).get('items', [])
        template_list.sort(key=itemgetter('creationTimestamp'))
        try:
            template_details = next(iter(template_list))
        except StopIteration:
            raise Exception(f"template {template} not found")
        template_details = NSDict(template_details)
        # name is above properties, so stick it into properties in order to just
        # return properties
        template_details.properties.name = template_details.name
        template_details.properties.url = template_details.selfLink
        return template_details.properties

    @lru_cache(maxsize=None)
    def machine_type(self, machine_type, project=None, zone=None):
        """  """
        if project is None:
            project = self.cfg.project
        if zone:
            with self.sync_compute() as compute:
                machine_details = ensure_execute(compute.machineTypes().get(
                    project=project, zone=zone, machineType=machine_type
                ))
        else:
            machines = defaultdict(dict)
            page = None
            with self.sync_compute() as compute:
                while True:
                    op = compute.machineTypes().aggregatedList(
                        project=project, pageToken=page)
                    result = ensure_execute(op)
                    page = result.get('nextPageToken')
                    machine_iter = chain.from_iterable(
                        m['machineTypes'] for m in result['items'].values() if
                        'machineTypes' in m
                    )
                    for machine in machine_iter:
                        name = machine['name']
                        zone = machine['zone']
                        machines[name][zone] = machine
    
                    if not page:
                        break
            # without a zone, just get the first one
            machine_details = next(iter(machines[machine_type].values()))
        return NSDict(machine_details)


class Config(NSDict):
    """ Loads config from yaml and holds values in nested namespaces """

    # PROPERTIES defines which properties in slurm.jinja.schema are included
    #   in the config file. SAVED_PROPS are saved to file via save_config.
    SAVED_PROPS = (
        'project',
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
        'templates',
        'partitions',
    )
    PROPERTIES = (
        *SAVED_PROPS,
        'munge_key',
        'jwt_key',
        'external_compute_ips',
        'controller_secondary_disk',
        'suspend_time',
        'login_node_count',
        'cloudsql',
    )

    def __init__(self, *args, **kwargs):
        super(Config, self).__init__(*args, **kwargs)

    @classmethod
    def new_config(cls, properties):
        # If k is ever not found, None will be inserted as the value
        cfg = cls({k: properties.setdefault(k, None) for k in cls.PROPERTIES})

        for netstore in (*cfg.network_storage, *(cfg.login_network_storage or []),
                         *chain(*(p.network_storage for p in
                                  (cfg.partitions or {}).values()))):
            if netstore.server_ip == '$controller':
                netstore.server_ip = cfg.cluster_name + '-controller'
        return cfg

    @classmethod
    def load_config(cls, path):
        config = yaml.safe_load(Path(path).read_text())
        return cls(config)

    def save_config(self, path):
        save_dict = Config([(k, self[k]) for k in self.SAVED_PROPS])
        Path(path).write_text(yaml.dump(save_dict, Dumper=Dumper))


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
                sleep(sleep)
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
    log.info(f"Waiting for operation {operation['id']} to finish...")
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
            log.info(f"Operation {operation['id']} done.")
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
