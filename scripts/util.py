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

import httplib2
import logging
import logging.config
import os
import re
import shlex
import socket
import subprocess
import sys
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, Future
from contextlib import contextmanager
from functools import lru_cache, reduce
from itertools import chain, compress, islice
from operator import itemgetter
from pathlib import Path
from time import sleep
from urllib import parse

import google.auth
import googleapiclient.discovery
import google_auth_httplib2
from googleapiclient.http import set_user_agent

from requests import get as get_url
from requests.exceptions import RequestException

import yaml
from addict import Dict as NSDict


USER_AGENT = "Slurm_GCP_Scripts/1.5 (GPN:SchedMD)"
API_REQ_LIMIT = 1000
ENV_CONFIG_YAML = os.getenv('SLURM_CONFIG_YAML')
if ENV_CONFIG_YAML:
    CONFIG_FILE = Path(ENV_CONFIG_YAML)
else:
    CONFIG_FILE = Path(__file__).with_name('config.yaml')
log = logging.getLogger(__name__)
def_creds,  project = google.auth.default()

# readily available compute api handle
compute = None
# slurm-gcp config object, could be None if not available
cfg = None
# caching Lookup object
lkp = None

# load all directories as Paths into a dict-like namespace
dirs = NSDict({n: Path(p) for n, p in dict.items({
    'home': '/home',
    'apps': '/opt/apps',
    'slurm': '/slurm',
    'scripts': '/slurm/scripts',
    'munge': '/etc/munge',
    'secdisk': '/mnt/disks/sec',
    'log': '/var/log/slurm'
})})

slurmdirs = NSDict({n: Path(p) for n, p in dict.items({
    'prefix': '/usr/local',
    'etc': '/usr/local/etc/slurm',
    'state': '/var/spool/slurm',
})})


def publish_message(project_id, topic_id, message) -> None:
    """Publishes message to a Pub/Sub topic."""
    from google.cloud import pubsub_v1
    from google import api_core

    publisher = pubsub_v1.PublisherClient()
    topic_path = publisher.topic_path(project_id, topic_id)

    retry_handler = api_core.retry.Retry(
        predicate=api_core.retry.if_exception_type(
            api_core.exceptions.Aborted,
            api_core.exceptions.DeadlineExceeded,
            api_core.exceptions.InternalServerError,
            api_core.exceptions.ResourceExhausted,
            api_core.exceptions.ServiceUnavailable,
            api_core.exceptions.Unknown,
            api_core.exceptions.Cancelled,
        ),
    )

    message_bytes = message.encode("utf-8")
    future = publisher.publish(topic_path, message_bytes, retry=retry_handler)
    result = future.exception()
    if result is not None:
        raise result

    print(f"Published message to '{topic_path}'.")


def parse_self_link(self_link: str):
    """Parse a selfLink url, extracting all useful values
    https://.../v1/projects/<project>/regions/<region>/...
    {'project': <project>, 'region': <region>, ...}
    can also extract zone, instance (name), image, etc
    """
    link_patt = re.compile(r'(?P<key>[^\/\s]+)s\/(?P<value>[^\s\/]+)')
    return NSDict(link_patt.findall(self_link))


def compute_service(credentials=None, user_agent=USER_AGENT):
    """Make thread-safe compute service handle
    creates a new Http for each request
    """
    if credentials is None:
        # TODO when can this fail? if it were to fail, credentials should be
        # left None
        credentials = def_creds

    def build_request(http, *args, **kwargs):
        new_http = httplib2.Http()
        if user_agent is not None:
            new_http = set_user_agent(new_http, user_agent)
        if credentials is not None:
            new_http = google_auth_httplib2.AuthorizedHttp(
                credentials, http=new_http)
        return googleapiclient.http.HttpRequest(new_http, *args, **kwargs)
    return googleapiclient.discovery.build(
        'compute', 'v1', requestBuilder=build_request,
        credentials=credentials,
    )


compute = compute_service()


def load_config_data(config):
    """load dict-like data into a config object"""
    cfg = NSDict(config)
    if not cfg.slurm_log_dir:
        cfg.slurm_log_dir = dirs.log
    if not cfg.slurm_bin_dir:
        cfg.slurm_bin_dir = slurmdirs.prefix/'bin'
    return cfg


def new_config(config):
    """initialize a new config object
    necessary defaults are handled here
    """
    cfg = load_config_data(config)

    network_storage_iter = filter(None, (
        *cfg.network_storage,
        *cfg.login_network_storage,
        *chain.from_iterable(
            p.network_storage for p in cfg.partitions.values()
        )
    ))
    for netstore in network_storage_iter:
        if netstore.server_ip == '$controller':
            netstore.server_ip = cfg.cluster_name + '-controller'
    return cfg


def config_from_metadata(use_cache=True):
    # get setup config from metadata
    cluster_name = instance_metadata('attributes/cluster_name')
    if not cluster_name:
        return None
    
    metadata_key = f'{cluster_name}-slurm-config'
    if use_cache:
        config_yaml = yaml.safe_load(project_metadata(metadata_key))
    else:
        config_yaml = yaml.safe_load(project_metadata.__wrapped__(metadata_key))
    cfg = new_config(config_yaml)  # noqa F811
    return cfg


def load_config_file(path):
    """load config from file"""
    content = None
    try:
        content = yaml.safe_load(Path(path).read_text())
    except FileNotFoundError:
        log.error(f"config file not found: {path}")
        return None
    return load_config_data(content)


def save_config(cfg, path):
    """save given config to file at path"""
    Path(path).write_text(yaml.dump(cfg, Dumper=Dumper))


def config_root_logger(caller_logger, level='DEBUG', util_level=None,
                       stdout=True, logfile=None):
    """configure the root logger, disabling all existing loggers
    """
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
    logging.getLogger(caller_logger).disabled = False


def handle_exception(exc_type, exc_value, exc_trace):
    """log exceptions other than KeyboardInterrupt"""
    # TODO does this work?
    if not issubclass(exc_type, KeyboardInterrupt):
        log.exception("Fatal exception",
                      exc_info=(exc_type, exc_value, exc_trace))
    sys.__excepthook__(exc_type, exc_value, exc_trace)


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
    """nonblocking spawn of subprocess"""
    if not quiet:
        log.debug(f"spawn: {cmd}")
    args = cmd if shell else shlex.split(cmd)
    return subprocess.Popen(args, shell=shell, **kwargs)


@contextmanager
def cd(path):
    """Change working directory for context"""
    prev = Path.cwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(prev)


def cached_property(f):
    return property(lru_cache()(f))


def seperate(pred, coll):
    """filter into 2 lists based on pred returning True or False
       returns ([False], [True])
    """
    return reduce(lambda acc, el: acc[pred(el)].append(el) or acc,
                  coll, ([], []))


def chunked(iterable, n=API_REQ_LIMIT):
    """group iterator into chunks of max size n"""
    it = iter(iterable)
    while True:
        chunk = list(islice(it, n))
        if not chunk:
            return
        yield chunk


ROOT_URL = 'http://metadata.google.internal/computeMetadata/v1'


def get_metadata(path, root=ROOT_URL):
    """Get metadata relative to metadata/computeMetadata/v1"""
    HEADERS = {'Metadata-Flavor': 'Google'}
    url = f'{root}/{path}'
    try:
        resp = get_url(url, headers=HEADERS)
        resp.raise_for_status()
        return resp.text
    except RequestException:
        log.error(f"Error while getting metadata from {url}")
        return None


@lru_cache(maxsize=None)
def instance_metadata(path):
    """Get instance metadata"""
    return get_metadata(path, root=f"{ROOT_URL}/instance")


@lru_cache(maxsize=None)
def project_metadata(key):
    """Get project metadata project/attributes/<cluster_name>-<path>"""
    return get_metadata(key, root=f"{ROOT_URL}/project/attributes")


def retry_exception(exc):
    """return true for exceptions that should always be retried"""
    retry_errors = (
        "Rate Limit Exceeded",
        "Quota Exceeded",
    )
    return any(e in str(exc) for e in retry_errors)


def ensure_execute(request):
    """Handle rate limits and socket time outs"""

    retry = 0
    wait = 1
    max_wait = 60
    while True:
        try:
            return request.execute()

        except googleapiclient.errors.HttpError as e:
            if retry_exception(e):
                retry += 1
                wait = min(wait*2, max_wait)
                log.error(f"retry:{retry} sleep:{wait} '{e}'")
                sleep(wait)
                continue
            raise

        except socket.timeout as e:
            # socket timed out, try again
            log.debug(e)

        except Exception as e:
            log.error(e, exc_info=True)
            raise

        break


def batch_execute(requests, compute=compute, retry_cb=None):
    """execute list or dict<req_id, request> as batch requests
    retry if retry_cb returns true
    """
    BATCH_LIMIT = 1000
    if not isinstance(requests, dict):
        requests = {
            str(k): v for k, v in enumerate(requests)
        }  # rid generated here
    done = {}
    failed = {}

    def batch_callback(rid, resp, exc):
        if exc is not None:
            log.error(f"compute request exception {rid}: {exc}")
            if not retry_exception(exc):
                req = requests.pop(rid)
                failed[rid] = (req, exc)
        else:
            # if retry_cb is set, don't move to done until it returns false
            if retry_cb is None or not retry_cb(resp):
                requests.pop(rid)
                done[rid] = resp

    while requests:
        batch = compute.new_batch_http_request(callback=batch_callback)
        chunk = list(islice(requests.items(), BATCH_LIMIT))
        for rid, req in chunk:
            batch.add(req, request_id=rid)
        ensure_execute(batch)
    return done, failed


def wait_request(operation, project=project, compute=compute):
    """makes the appropriate wait request for a given operation"""
    if 'zone' in operation:
        req = compute.zoneOperations().wait(
            project=project,
            zone=operation['zone'].split('/')[-1],
            operation=operation['name'])
    elif 'region' in operation:
        req = compute.regionOperations().wait(
            project=project,
            region=operation['region'].split('/')[-1],
            operation=operation['name'])
    else:
        req = compute.globalOperations().wait(
            project=project,
            operation=operation['name'])
    return req


def wait_for_operations(operations, project=project, compute=compute):
    """wait for all operations"""
    def operation_retry(resp):
        return resp['status'] != 'DONE'
    requests = [wait_request(op) for op in operations]
    return batch_execute(requests, retry_cb=operation_retry)


def wait_for_operation(operation, project=project, compute=compute):
    """wait for given operation"""
    print('Waiting for operation to finish...')
    wait_req = wait_request(operation)

    while True:
        result = ensure_execute(wait_req)
        if result['status'] == 'DONE':
            print("done.")
            return result


def get_group_operations(operation, project=project, compute=compute):
    """get list of operations associated with group id"""

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


class Dumper(yaml.SafeDumper):
    """Add representers for pathlib.Path and NSDict for yaml serialization
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
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


class Lookup:
    """ Wrapper class for cached data access
    """
    regex = r'(?P<name>[^\s\-]+)-(?P<partition>[^\s\-]+)-(?P<group>\S+)-(?P<index>\d+)'
    node_desc_regex = re.compile(regex)

    def __init__(self, cfg=None):
        self._cfg = cfg or NSDict()

    @property
    def cfg(self):
        return self._cfg

    @property
    def project(self):
        return self._cfg.project or project

    @property
    def control_host(self):
        if self._cfg.cluster_name:
            return f'{self._cfg.cluster_name}-controller'
        return None

    @property
    def template_map(self):
        return self._cfg.template_map

    @cached_property
    def instance_role(self):
        return instance_metadata('attributes/instance_type')

    @cached_property
    def compute(self):
        # TODO evaluate when we need to use google_app_cred_path
        if self._cfg.google_app_cred_path:
            os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = self._cfg.google_app_cred_path
        return compute_service()

    @cached_property
    def hostname(self):
        return socket.gethostname()

    @cached_property
    def zone(self):
        return instance_metadata('zone')

    @property
    def exclusive(self):
        return bool(self._cfg.exclusive or self._cfg.enable_placement)

    @lru_cache(maxsize=None)
    def _node_desc(self, node_name):
        """Get parts from node name"""
        if not node_name:
            node_name = self.hostname
        m = self.node_desc_regex.match(node_name)
        if not m:
            raise Exception(f"node name {node_name} is not valid")
        return NSDict(m.groupdict())

    def node_partition_name(self, node_name=None):
        return self._node_desc(node_name).partition

    def node_group_name(self, node_name=None):
        return self._node_desc(node_name).group

    def node_index(self, node_name=None):
        return self._node_desc(node_name).index

    def node_partition(self, node_name=None):
        return self._cfg.partitions[self.node_partition_name(node_name)]

    def node_group(self, node_name=None):
        group_name = self.node_group_name(node_name)
        return self.node_partition(node_name).partition_nodes[group_name]

    def node_template(self, node_name=None):
        return self.node_group(node_name).instance_template

    def node_template_info(self, node_name=None):
        return self.template_info(self.node_template(node_name))

    @lru_cache(maxsize=1)
    def instances(self, project=None, cluster_name=None):
        cluster_name = cluster_name or self._cfg.cluster_name
        project = project or self.project
        fields = 'items.zones.instances(name,zone,status,machineType,metadata),nextPageToken'
        flt = f'name={cluster_name}-*'
        act = self.compute.instances()
        op = act.aggregatedList(project=project, fields=fields, filter=flt)

        def properties(inst):
            """change instance properties to a preferred format"""
            inst['zone'] = inst['zone'].split('/')[-1]
            inst['machineType'] = inst['machineType'].split('/')[-1]
            # metadata is fetched as a dict of dicts like:
            # {'key': key, 'value': value}, kinda silly
            metadata = {i['key']: i['value']
                        for i in inst['metadata']['items']}
            inst['role'] = metadata['instance_type']
            del inst['metadata']  # no need to store all the metadata
            return inst
        while op is not None:
            result = ensure_execute(op)
            instances = {
                inst['name']: properties(inst) for inst in chain.from_iterable(
                    m['instances'] for m in result['items'].values()
                )
            }
            op = act.aggregatedList_next(op, result)
        return NSDict(instances)

    def instance(self, instance_name, project=None, cluster_name=None):
        instances = self.instances(project=project,
                                   cluster_name=cluster_name)
        return instances.get(instance_name)

    @lru_cache(maxsize=1)
    def machine_types(self, project=None):
        project = project or self.project
        field_names = 'name,zone,guestCpus,memoryMb,accelerators'
        fields = f'items.zones.machineTypes({field_names}),nextPageToken'

        machines = defaultdict(dict)
        act = self.compute.machineTypes()
        op = act.aggregatedList(project=project, fields=fields)
        while op is not None:
            result = ensure_execute(op)
            machine_iter = chain.from_iterable(
                m['machineTypes'] for m in result['items'].values()
                if 'machineTypes' in m
            )
            for machine in machine_iter:
                name = machine['name']
                zone = machine['zone']
                machines[name][zone] = machine

            op = act.aggregatedList_next(op, result)
        return machines

    def machine_type(self, machine_type, project=None, zone=None):
        """  """
        if zone:
            project = project or self.project
            machine_info = ensure_execute(self.compute.machineTypes().get(
                project=project, zone=zone, machineType=machine_type
            ))
        else:
            machines = self.machine_types(project=project)
            machine_info = next(iter(machines[machine_type].values()))
        return NSDict(machine_info)

    def template_machine_conf(self, template_link, project=None, zone=None):

        template = self.template_info(template_link)
        template.machine_info = self.machine_type(template.machineType,
                                                  zone=zone)
        machine = template.machine_info
        machine_conf = NSDict()
        # TODO how is smt passed?
        #machine['cpus'] = machine['guestCpus'] // (1 if part.image_hyperthreads else 2) or 1
        machine_conf.cpus = machine.guestCpus
        # Because the actual memory on the host will be different than
        # what is configured (e.g. kernel will take it). From
        # experiments, about 16 MB per GB are used (plus about 400 MB
        # buffer for the first couple of GB's. Using 30 MB to be safe.
        gb = machine.memoryMb // 1024
        machine_conf.memory = machine.memoryMb - (400 + (30 * gb))
        return machine_conf

    @lru_cache(maxsize=None)
    def template_info(self, template_link, project=None):
        project = project or self.project
        template_name = template_link.split('/')[-1]

        template = ensure_execute(
            self.compute.instanceTemplates().get(
                project=project, instanceTemplate=template_name)
        ).get('properties')
        template = NSDict(template)
        # name and link are not in properties, so stick them in
        template.name = template_name
        template.link = template_link
        # TODO delete metadata to reduce memory footprint?
        #del template.metadata

        # translate gpus into an easier-to-read format
        if template.guestAccelerators:
            template.gpu_type = template.guestAccelerators[0].acceleratorType
            template.gpu_count = template.guestAccelerators[0].acceleratorCount
        else:
            template.gpu_type = None
            template.gpu_count = 0

        return template


# Define late globals
cfg = load_config_file(CONFIG_FILE)
if not cfg:
    log.warning(f"{CONFIG_FILE} not found")
    cfg = config_from_metadata()
    if cfg:
        save_config(cfg, CONFIG_FILE)
    else:
        log.error("config metadata unavailable")

lkp = Lookup(cfg)
