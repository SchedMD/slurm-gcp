#!/usr/bin/env python3

# Copyright (C) SchedMD LLC.
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

import inspect
import json
import httplib2
import importlib.util
import logging
import logging.config
import os
import re
import shelve
import shlex
import shutil
import socket
import subprocess
import sys
import tempfile
from collections import defaultdict, namedtuple
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from functools import lru_cache, reduce, partialmethod
from itertools import chain, compress, islice
from pathlib import Path
from time import sleep, time

required_modules = [
    ("googleapiclient", "google-api-python-client"),
    ("requests", "requests"),
    ("yaml", "yaml"),
    ("addict", "addict"),
]
missing_imports = False
for module, name in required_modules:
    if importlib.util.find_spec(module) is None:
        missing_imports = True
        print(f"ERROR: Missing Python module '{module} (pip:{name})'")
if missing_imports:
    print("Aborting due to missing Python modules")
    exit(1)

import google.auth  # noqa: E402
from google.oauth2 import service_account  # noqa: E402
import googleapiclient.discovery  # noqa: E402
import google_auth_httplib2  # noqa: E402
from googleapiclient.http import set_user_agent  # noqa: E402

from requests import get as get_url  # noqa: E402
from requests.exceptions import RequestException  # noqa: E402

import yaml  # noqa: E402
from addict import Dict as NSDict  # noqa: E402

optional_modules = [
    ("google.cloud.pubsub", "google-cloud-pubsub"),
    ("google.cloud.secretmanager", "google-cloud-secret-manager"),
]
for module, name in optional_modules:
    if importlib.util.find_spec(module) is None:
        print(f"WARNING: Missing Python module '{module}' (pip:{name}) ")

USER_AGENT = "Slurm_GCP_Scripts/1.5 (GPN:SchedMD)"
ENV_CONFIG_YAML = os.getenv("SLURM_CONFIG_YAML")
if ENV_CONFIG_YAML:
    CONFIG_FILE = Path(ENV_CONFIG_YAML)
else:
    CONFIG_FILE = Path(__file__).with_name("config.yaml")
API_REQ_LIMIT = 2000
URI_REGEX = r"[a-z]([-a-z0-9]*[a-z0-9])?"

def_creds, auth_project = google.auth.default()
Path.mkdirp = partialmethod(Path.mkdir, parents=True, exist_ok=True)

scripts_dir = next(
    p for p in (Path(__file__).parent, Path("/slurm/scripts")) if p.is_dir()
)

# readily available compute api handle
compute = None
# slurm-gcp config object, could be None if not available
cfg = None
# caching Lookup object
lkp = None

# load all directories as Paths into a dict-like namespace
dirs = NSDict(
    {
        n: Path(p)
        for n, p in dict.items(
            {
                "home": "/home",
                "apps": "/opt/apps",
                "slurm": "/slurm",
                "scripts": scripts_dir,
                "custom_scripts": "/slurm/custom_scripts",
                "munge": "/etc/munge",
                "secdisk": "/mnt/disks/sec",
                "log": "/var/log/slurm",
            }
        )
    }
)

slurmdirs = NSDict(
    {
        n: Path(p)
        for n, p in dict.items(
            {
                "prefix": "/usr/local",
                "etc": "/usr/local/etc/slurm",
                "state": "/var/spool/slurm",
            }
        )
    }
)


class LogFormatter(logging.Formatter):
    """adds logging flags to the levelname in log records"""

    def format(self, record):
        new_fmt = self._fmt
        flag = getattr(record, "flag", None)
        if flag is not None:
            start, level, end = new_fmt.partition("%(levelname)s")
            if level:
                new_fmt = f"{start}{level}(%(flag)s){end}"
        # insert function name if record level is DEBUG
        if record.levelno < logging.INFO:
            prefix, msg, suffix = new_fmt.partition("%(message)s")
            new_fmt = f"{prefix}%(funcName)s: {msg}{suffix}"
        self._style._fmt = new_fmt
        return super().format(record)


class FlagLogAdapter(logging.LoggerAdapter):
    """creates log adapters that add a flag to the log record,
    allowing it to be filtered"""

    def __init__(self, logger, flag, extra=None):
        if extra is None:
            extra = {}
        self.flag = flag
        super().__init__(logger, extra)

    @property
    def enabled(self):
        return cfg.extra_logging_flags.get(self.flag, False)

    def process(self, msg, kwargs):
        extra = kwargs.setdefault("extra", {})
        extra.update(self.extra)
        extra["flag"] = self.flag
        return msg, kwargs


logging.basicConfig(level=logging.INFO, stream=sys.stdout)
log = logging.getLogger(__name__)
logging_flags = [
    "trace_api",
    "subproc",
    "hostlists",
    "subscriptions",
]
log_trace_api = FlagLogAdapter(log, "trace_api")
log_subproc = FlagLogAdapter(log, "subproc")
log_hostlists = FlagLogAdapter(log, "hostlists")
log_subscriptions = FlagLogAdapter(log, "subscriptions")


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


def access_secret_version(project_id, secret_id, version_id="latest"):
    """
    Access the payload for the given secret version if one exists. The version
    can be a version number as a string (e.g. "5") or an alias (e.g. "latest").
    """
    from google.cloud import secretmanager
    from google.api_core import exceptions

    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{project_id}/secrets/{secret_id}/versions/{version_id}"
    try:
        response = client.access_secret_version(request={"name": name})
        log.debug(f"Secret '{name}' was found.")
        payload = response.payload.data.decode("UTF-8")
    except exceptions.NotFound:
        log.debug(f"Secret '{name}' was not found!")
        payload = None

    return payload


def parse_self_link(self_link: str):
    """Parse a selfLink url, extracting all useful values
    https://.../v1/projects/<project>/regions/<region>/...
    {'project': <project>, 'region': <region>, ...}
    can also extract zone, instance (name), image, etc
    """
    link_patt = re.compile(r"(?P<key>[^\/\s]+)s\/(?P<value>[^\s\/]+)")
    return NSDict(link_patt.findall(self_link))


def trim_self_link(link: str):
    """get resource name from self link url, eg.
    https://.../v1/projects/<project>/regions/<region>
    -> <region>
    """
    try:
        return link[link.rindex("/") + 1 :]
    except ValueError:
        raise Exception(f"'/' not found, not a self link: '{link}' ")


def subscription_list(project_id=None, page_size=None, slurm_cluster_name=None):
    """List pub/sub subscription"""
    from google.cloud import pubsub_v1

    if project_id is None:
        project_id = auth_project
    if slurm_cluster_name is None:
        slurm_cluster_name = lkp.cfg.slurm_cluster_name

    subscriber = pubsub_v1.SubscriberClient()

    subscriptions = []
    # get first page
    page = subscriber.list_subscriptions(
        request={
            "project": f"projects/{project_id}",
            "page_size": page_size,
        }
    )
    subscriptions.extend(page.subscriptions)
    # walk the pages
    while page.next_page_token:
        page = subscriber.list_subscriptions(
            request={
                "project": f"projects/{project_id}",
                "page_token": page.next_page_token,
                "page_size": page_size,
            }
        )
        subscriptions.extend(page.subscriptions)
    # manual filter by label
    subscriptions = [
        s
        for s in subscriptions
        if s.labels.get("slurm_cluster_name") == slurm_cluster_name
    ]

    return subscriptions


def subscription_create(subscription_id, project_id=None):
    """Create pub/sub subscription"""
    from google.cloud import pubsub_v1
    from google.api_core import exceptions

    if project_id is None:
        project_id = lkp.project
    topic_id = lkp.cfg.pubsub_topic_id

    publisher = pubsub_v1.PublisherClient()
    subscriber = pubsub_v1.SubscriberClient()
    topic_path = publisher.topic_path(project_id, topic_id)
    subscription_path = subscriber.subscription_path(project_id, subscription_id)

    with subscriber:
        request = {
            "name": subscription_path,
            "topic": topic_path,
            "ack_deadline_seconds": 60,
            "labels": {
                "slurm_cluster_name": cfg.slurm_cluster_name,
            },
        }
        try:
            subscription = subscriber.create_subscription(request=request)
            log.info(f"Subscription created: {subscription_path}")
            log_subscriptions.debug(f"{subscription}")
        except exceptions.AlreadyExists:
            log.info(f"Subscription '{subscription_path}' already exists!")


def subscription_delete(subscription_id, project_id=None):
    """Delete pub/sub subscription"""
    from google.cloud import pubsub_v1
    from google.api_core import exceptions

    if project_id is None:
        project_id = lkp.project

    subscriber = pubsub_v1.SubscriberClient()
    subscription_path = subscriber.subscription_path(project_id, subscription_id)

    with subscriber:
        try:
            subscriber.delete_subscription(request={"subscription": subscription_path})
            log.info(f"Subscription deleted: {subscription_path}.")
        except exceptions.NotFound:
            log.info(f"Subscription '{subscription_path}' not found!")


def execute_with_futures(func, seq):
    with ThreadPoolExecutor() as exe:
        futures = []
        for i in seq:
            future = exe.submit(func, i)
            futures.append(future)
        for future in futures:
            result = future.exception()
            if result is not None:
                raise result


def map_with_futures(func, seq):
    with ThreadPoolExecutor() as exe:
        futures = []
        for i in seq:
            future = exe.submit(func, i)
            futures.append(future)
        for future in futures:
            yield future.result(), future.exception()


def is_exclusive_node(node):
    partition = lkp.node_partition(node)
    return not lkp.node_is_static(node) and (
        partition.enable_job_exclusive or partition.enable_placement_groups
    )


def compute_service(credentials=None, user_agent=USER_AGENT, version="v1"):
    """Make thread-safe compute service handle
    creates a new Http for each request
    """
    try:
        key_path = os.environ["GOOGLE_APPLICATION_CREDENTIALS"]
    except KeyError:
        key_path = None
    if key_path is not None:
        credentials = service_account.Credentials.from_service_account_file(
            key_path, scopes=["https://www.googleapis.com/auth/cloud-platform"]
        )
    elif credentials is None:
        credentials = def_creds

    def build_request(http, *args, **kwargs):
        new_http = httplib2.Http()
        if user_agent is not None:
            new_http = set_user_agent(new_http, user_agent)
        if credentials is not None:
            new_http = google_auth_httplib2.AuthorizedHttp(credentials, http=new_http)
        return googleapiclient.http.HttpRequest(new_http, *args, **kwargs)

    log.debug(f"Using version={version} of Google Compute Engine API")
    return googleapiclient.discovery.build(
        "compute",
        version,
        requestBuilder=build_request,
        credentials=credentials,
    )


compute = compute_service()


def load_config_data(config):
    """load dict-like data into a config object"""
    cfg = NSDict(config)
    if not cfg.slurm_log_dir:
        cfg.slurm_log_dir = dirs.log
    if not cfg.slurm_bin_dir:
        cfg.slurm_bin_dir = slurmdirs.prefix / "bin"
    if not cfg.slurm_control_host:
        cfg.slurm_control_host = f"{cfg.slurm_cluster_name}-controller"

    if not cfg.enable_debug_logging and isinstance(cfg.enable_debug_logging, NSDict):
        cfg.enable_debug_logging = False
    cfg.extra_logging_flags = NSDict(
        {flag: cfg.extra_logging_flags.get(flag, False) for flag in logging_flags}
    )
    return cfg


def new_config(config):
    """initialize a new config object
    necessary defaults are handled here
    """
    cfg = load_config_data(config)

    network_storage_iter = filter(
        None,
        (
            *cfg.network_storage,
            *cfg.login_network_storage,
            *chain.from_iterable(p.network_storage for p in cfg.partitions.values()),
        ),
    )
    for netstore in network_storage_iter:
        if netstore.server_ip is None or netstore.server_ip == "$controller":
            netstore.server_ip = cfg.slurm_control_host
    return cfg


def config_from_metadata():
    # get setup config from metadata
    slurm_cluster_name = instance_metadata("attributes/slurm_cluster_name")
    if not slurm_cluster_name:
        return None

    metadata_key = f"{slurm_cluster_name}-slurm-config"
    RETRY_WAIT = 5
    for i in range(8):
        if i:
            log.error(f"config not found in project metadata, retry {i}")
            sleep(RETRY_WAIT)
        config_yaml = project_metadata.__wrapped__(metadata_key)
        if config_yaml is not None:
            break
    else:
        return None
    cfg = new_config(yaml.safe_load(config_yaml))
    return cfg


def load_config_file(path):
    """load config from file"""
    content = None
    try:
        content = yaml.safe_load(Path(path).read_text())
    except FileNotFoundError:
        log.error(f"config file not found: {path}")
        return NSDict()
    return load_config_data(content)


def save_config(cfg, path):
    """save given config to file at path"""
    Path(path).write_text(yaml.dump(cfg, Dumper=Dumper))


def filter_logging_flags(record):
    """logging filter for flags
    if there are no flags, always pass. If there are flags, only pass if a flag
    matches an enabled flag in cfg.extra_logging_flags"""
    flag = getattr(record, "flag", None)
    if flag is None:
        return True
    return cfg.extra_logging_flags.get(flag, False)


def owned_file_handler(filename):
    """create file handler"""
    if filename is None:
        return None
    chown_slurm(filename)
    return logging.handlers.WatchedFileHandler(filename, delay=True)


def config_root_logger(caller_logger, level="DEBUG", stdout=True, logfile=None):
    """configure the root logger, disabling all existing loggers"""
    handlers = list(compress(("stdout_handler", "file_handler"), (stdout, logfile)))

    config = {
        "version": 1,
        "disable_existing_loggers": True,
        "formatters": {
            "standard": {
                "()": LogFormatter,
                "fmt": "%(levelname)s: %(message)s",
            },
            "stamp": {
                "()": LogFormatter,
                "fmt": "%(asctime)s %(levelname)s: %(message)s",
            },
        },
        "filters": {
            "logging_flags": {"()": lambda: filter_logging_flags},
        },
        "handlers": {
            "stdout_handler": {
                "level": logging.DEBUG,
                "formatter": "standard",
                "class": "logging.StreamHandler",
                "stream": sys.stdout,
                "filters": ["logging_flags"],
            },
            "file_handler": {
                "()": owned_file_handler,
                "level": logging.DEBUG,
                "formatter": "stamp",
                "filters": ["logging_flags"],
                "filename": logfile,
            },
        },
        "root": {
            "handlers": handlers,
            "level": level,
        },
    }
    if not logfile:
        del config["handlers"]["file_handler"]
    logging.config.dictConfig(config)
    loggers = (
        __name__,
        "resume",
        "suspend",
        "slurmsync",
        "setup",
        caller_logger,
    )
    for logger in map(logging.getLogger, loggers):
        logger.disabled = False


def log_api_request(request):
    """log.trace info about a compute API request"""
    if log_trace_api.enabled:
        # output the whole request object as pretty yaml
        # the body is nested json, so load it as well
        rep = json.loads(request.to_json())
        if rep.get("body", None) is not None:
            rep["body"] = json.loads(rep["body"])
        pretty_req = yaml.safe_dump(rep).rstrip()
        # label log message with the calling function
        log_trace_api.debug(f"{inspect.stack()[1].function}:\n{pretty_req}")


def handle_exception(exc_type, exc_value, exc_trace):
    """log exceptions other than KeyboardInterrupt"""
    # TODO does this work?
    if not issubclass(exc_type, KeyboardInterrupt):
        log.exception("Fatal exception", exc_info=(exc_type, exc_value, exc_trace))
    sys.__excepthook__(exc_type, exc_value, exc_trace)


def run(
    cmd,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    shell=False,
    timeout=None,
    check=True,
    universal_newlines=True,
    **kwargs,
):
    """Wrapper for subprocess.run() with convenient defaults"""
    log_subproc.debug(f"run: {cmd}")
    args = cmd if shell else shlex.split(cmd)
    result = subprocess.run(
        args,
        stdout=stdout,
        stderr=stderr,
        shell=shell,
        timeout=timeout,
        check=check,
        universal_newlines=universal_newlines,
        **kwargs,
    )
    return result


def spawn(cmd, quiet=False, shell=False, **kwargs):
    """nonblocking spawn of subprocess"""
    if not quiet:
        log_subproc.debug(f"spawn: {cmd}")
    args = cmd if shell else shlex.split(cmd)
    return subprocess.Popen(args, shell=shell, **kwargs)


def chown_slurm(path, mode=None):
    if path.exists():
        if mode:
            path.chmod(mode)
    else:
        path.parent.mkdirp()
        if mode:
            path.touch(mode=mode)
        else:
            path.touch()
    try:
        shutil.chown(path, user="slurm", group="slurm")
    except LookupError:
        log.warning(f"User 'slurm' does not exist. Cannot 'chown slurm:slurm {path}'.")
    except PermissionError:
        log.warning(f"Not authorized to 'chown slurm:slurm {path}'.")
    except Exception as err:
        log.error(err)


@contextmanager
def cd(path):
    """Change working directory for context"""
    prev = Path.cwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(prev)


def with_static(**kwargs):
    def decorate(func):
        for var, val in kwargs.items():
            setattr(func, var, val)
        return func

    return decorate


def cached_property(f):
    return property(lru_cache()(f))


def separate(pred, coll):
    """filter into 2 lists based on pred returning True or False
    returns ([False], [True])
    """
    return reduce(lambda acc, el: acc[pred(el)].append(el) or acc, coll, ([], []))


def chunked(iterable, n=API_REQ_LIMIT):
    """group iterator into chunks of max size n"""
    it = iter(iterable)
    while True:
        chunk = list(islice(it, n))
        if not chunk:
            return
        yield chunk


def groupby_unsorted(seq, key):
    indices = defaultdict(list)
    for i, el in enumerate(seq):
        indices[key(el)].append(i)
    for k, idxs in indices.items():
        yield k, (seq[i] for i in idxs)


def backoff_delay(start, cap=None, floor=None, mul=1, max_total=None, max_count=None):
    assert start > 0
    assert mul > 0
    count = 1
    wait = total = start
    yield start
    while (max_total is None or total < max_total) and (
        max_count is None or count < max_count
    ):
        wait *= mul
        if floor is not None:
            wait = max(floor, wait)
        if cap is not None:
            wait = min(cap, wait)
        total += wait
        count += 1
        yield wait
    return


ROOT_URL = "http://metadata.google.internal/computeMetadata/v1"


def get_metadata(path, root=ROOT_URL):
    """Get metadata relative to metadata/computeMetadata/v1"""
    HEADERS = {"Metadata-Flavor": "Google"}
    url = f"{root}/{path}"
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
    """Get project metadata project/attributes/<slurm_cluster_name>-<path>"""
    return get_metadata(key, root=f"{ROOT_URL}/project/attributes")


def nodeset_prefix(node_group, part_name):
    return f"{cfg.slurm_cluster_name}-{part_name}-{node_group.group_name}"


def nodeset_lists(node_group, part_name):
    """Return static and dynamic nodenames given a partition node type
    definition
    """

    def node_range(count, start=0):
        end = start + count - 1
        return f"{start}" if count == 1 else f"[{start}-{end}]", end + 1

    prefix = nodeset_prefix(node_group, part_name)
    static_count = node_group.node_count_static
    dynamic_count = node_group.node_count_dynamic_max
    static_range, end = node_range(static_count) if static_count else (None, 0)
    dynamic_range, _ = node_range(dynamic_count, end) if dynamic_count else (None, 0)

    static_nodelist = f"{prefix}-{static_range}" if static_count else None
    dynamic_nodelist = f"{prefix}-{dynamic_range}" if dynamic_count else None
    return static_nodelist, dynamic_nodelist


def natural_sort(text):
    def atoi(text):
        return int(text) if text.isdigit() else text

    return [atoi(w) for w in re.split(r"(\d+)", text)]


def to_hostlist(nodenames):
    """make hostlist from list of node names"""
    # use tmp file because list could be large
    tmp_file = tempfile.NamedTemporaryFile(mode="w+t", delete=False)
    tmp_file.writelines("\n".join(sorted(nodenames, key=natural_sort)))
    tmp_file.close()

    hostlist = run(f"{lkp.scontrol} show hostlist {tmp_file.name}").stdout.rstrip()
    log_hostlists.debug(f"hostlist({len(nodenames)}): {hostlist}".format(hostlist))
    os.remove(tmp_file.name)
    return hostlist


def to_hostnames(nodelist):
    """make list of hostnames from hostlist expression"""
    if isinstance(nodelist, str):
        hostlist = nodelist
    else:
        hostlist = ",".join(nodelist)
    hostnames = run(f"{lkp.scontrol} show hostnames {hostlist}").stdout.splitlines()
    log_hostlists.debug(f"hostnames({len(hostnames)}) from {hostlist}")
    return hostnames


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
    for wait in backoff_delay(0.5, cap=60, mul=2, max_total=10 * 60):
        try:
            return request.execute()

        except googleapiclient.errors.HttpError as e:
            if retry_exception(e):
                retry += 1
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
        requests = {str(k): v for k, v in enumerate(requests)}  # rid generated here
    done = {}
    failed = {}
    timestamps = []
    rate_limited = False

    def batch_callback(rid, resp, exc):
        nonlocal rate_limited
        if exc is not None:
            log.error(f"compute request exception {rid}: {exc}")
            if retry_exception(exc):
                rate_limited = True
            else:
                req = requests.pop(rid)
                failed[rid] = (req, exc)
        else:
            # if retry_cb is set, don't move to done until it returns false
            if retry_cb is None or not retry_cb(resp):
                requests.pop(rid)
                done[rid] = resp

    def batch_request(reqs):
        batch = compute.new_batch_http_request(callback=batch_callback)
        for rid, req in reqs:
            batch.add(req, request_id=rid)
        return batch

    while requests:
        if timestamps:
            timestamps = [stamp for stamp in timestamps if stamp > time()]
        if rate_limited and timestamps:
            stamp = next(iter(timestamps))
            sleep(max(stamp - time(), 0))
            rate_limited = False
        # up to API_REQ_LIMIT (2000) requests
        # in chunks of up to BATCH_LIMIT (1000)
        batches = [
            batch_request(chunk)
            for chunk in chunked(islice(requests.items(), API_REQ_LIMIT), BATCH_LIMIT)
        ]
        timestamps.append(time() + 100)
        with ThreadPoolExecutor() as exe:
            futures = []
            for batch in batches:
                future = exe.submit(ensure_execute, batch)
                futures.append(future)
            for future in futures:
                result = future.exception()
                if result is not None:
                    raise result

    return done, failed


def wait_request(operation, project=None, compute=compute):
    """makes the appropriate wait request for a given operation"""
    if project is None:
        project = lkp.project
    if "zone" in operation:
        req = compute.zoneOperations().wait(
            project=project,
            zone=trim_self_link(operation["zone"]),
            operation=operation["name"],
        )
    elif "region" in operation:
        req = compute.regionOperations().wait(
            project=project,
            region=trim_self_link(operation["region"]),
            operation=operation["name"],
        )
    else:
        req = compute.globalOperations().wait(
            project=project, operation=operation["name"]
        )
    return req


def wait_for_operation(operation, project=None, compute=compute):
    """wait for given operation"""
    wait_req = wait_request(operation, project=project, compute=compute)

    while True:
        result = ensure_execute(wait_req)
        if result["status"] == "DONE":
            log_errors = " with errors" if "error" in result else ""
            log.debug(
                f"operation complete{log_errors}: type={result['operationType']}, name={result['name']}"
            )
            return result


def wait_for_operations(operations, project=None, compute=compute):
    return [
        wait_for_operation(op, project=project, compute=compute) for op in operations
    ]


def wait_for_operations_async(operations, project=None, compute=compute):
    """wait for all operations"""

    def operation_retry(resp):
        return resp["status"] != "DONE"

    requests = [wait_request(op, project=project, compute=compute) for op in operations]
    return batch_execute(requests, retry_cb=operation_retry)


def get_filtered_operations(
    op_filter,
    zone=None,
    region=None,
    only_global=False,
    project=None,
    compute=compute,
):
    """get list of operations associated with group id"""

    if project is None:
        project = lkp.project
    operations = []

    def get_aggregated_operations(items):
        # items is a dict of location key to value: dict(operations=<list of operations>) or an empty dict
        operations.extend(
            chain.from_iterable(
                ops["operations"] for ops in items.values() if "operations" in ops
            )
        )

    def get_list_operations(items):
        operations.extend(items)

    handle_items = get_list_operations
    if only_global:
        act = compute.globalOperations()
        op = act.list(project=project, filter=op_filter)
        nxt = act.list_next
    elif zone is not None:
        act = compute.zoneOperations()
        op = act.list(project=project, zone=zone, filter=op_filter)
        nxt = act.list_next
    elif region is not None:
        act = compute.regionOperations()
        op = act.list(project=project, region=region, filter=op_filter)
        nxt = act.list_next
    else:
        act = compute.globalOperations()
        op = act.aggregatedList(
            project=project, filter=op_filter, fields="items.*.operations,nextPageToken"
        )
        nxt = act.aggregatedList_next
        handle_items = get_aggregated_operations
    while op is not None:
        result = ensure_execute(op)
        handle_items(result["items"])
        op = nxt(op, result)
    return operations


def get_insert_operations(group_ids, flt=None, project=None, compute=compute):
    """get all insert operations from a list of operationGroupId"""
    if project is None:
        project = lkp.project
    if isinstance(group_ids, str):
        group_ids = group_ids.split(",")
    filters = [
        "operationType=insert",
        flt,
        " OR ".join(f"(operationGroupId={id})" for id in group_ids),
    ]
    return get_filtered_operations(" AND ".join(f"({f})" for f in filters if f))


class Dumper(yaml.SafeDumper):
    """Add representers for pathlib.Path and NSDict for yaml serialization"""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.add_representer(NSDict, self.represent_nsdict)
        self.add_multi_representer(Path, self.represent_path)

    @staticmethod
    def represent_nsdict(dumper, data):
        return dumper.represent_mapping("tag:yaml.org,2002:map", data.items())

    @staticmethod
    def represent_path(dumper, path):
        return dumper.represent_scalar("tag:yaml.org,2002:str", str(path))


class Lookup:
    """Wrapper class for cached data access"""

    regex = (
        r"^(?P<prefix>"
        r"(?P<name>[^\s\-]+)"
        r"-(?P<partition>[^\s\-]+)"
        r"-(?P<group>\S+)"
        r")"
        r"-(?P<node>"
        r"(?P<index>\d+)|"
        r"(?P<range>\[[\d,-]+\])"
        r")$"
    )
    node_desc_regex = re.compile(regex)

    def __init__(self, cfg=None):
        self._cfg = cfg or NSDict()
        self.template_cache_path = Path(__file__).parent / "template_info.cache"

    @property
    def cfg(self):
        return self._cfg

    @property
    def project(self):
        return self.cfg.project or auth_project

    @property
    def control_host(self):
        return self.cfg.slurm_control_host

    @property
    def scontrol(self):
        return Path(self.cfg.slurm_bin_dir if cfg else "") / "scontrol"

    @property
    def template_map(self):
        return self.cfg.template_map

    @cached_property
    def instance_role(self):
        return instance_metadata("attributes/slurm_instance_role")

    @cached_property
    def compute(self):
        # TODO evaluate when we need to use google_app_cred_path
        if self.cfg.google_app_cred_path:
            os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = self.cfg.google_app_cred_path
        return compute_service()

    @cached_property
    def hostname(self):
        return socket.gethostname()

    @cached_property
    def zone(self):
        return instance_metadata("zone")

    @property
    def enable_job_exclusive(self):
        return bool(self.cfg.enable_job_exclusive or self.cfg.enable_placement)

    @lru_cache(maxsize=None)
    def _node_desc(self, node_name):
        """Get parts from node name"""
        if not node_name:
            node_name = self.hostname
        m = self.node_desc_regex.match(node_name)
        if not m:
            raise Exception(f"node name {node_name} is not valid")
        return NSDict(m.groupdict())

    def node_prefix(self, node_name=None):
        return self._node_desc(node_name).prefix

    def node_partition_name(self, node_name=None):
        return self._node_desc(node_name).partition

    def node_group_name(self, node_name=None):
        return self._node_desc(node_name).group

    def node_index(self, node_name=None):
        return int(self._node_desc(node_name).index)

    def node_partition(self, node_name=None):
        return self.cfg.partitions[self.node_partition_name(node_name)]

    def node_group(self, node_name=None):
        group_name = self.node_group_name(node_name)
        return self.node_partition(node_name).partition_nodes[group_name]

    def node_template(self, node_name=None):
        return self.node_group(node_name).instance_template

    def node_template_info(self, node_name=None):
        return self.template_info(self.node_template(node_name))

    def node_region(self, node_name=None):
        partition = self.node_partition(node_name)
        return parse_self_link(partition.subnetwork).region

    def node_is_static(self, node_name=None):
        node_group = self.node_group(node_name)
        return self.node_index(node_name) < node_group.node_count_static

    @lru_cache(maxsize=1)
    def static_nodelist(self):
        return list(
            filter(
                None,
                (
                    nodeset_lists(node, part.partition_name)[0]
                    for part in self.cfg.partitions.values()
                    for node in part.partition_nodes.values()
                ),
            )
        )

    @lru_cache(maxsize=None)
    def slurm_nodes(self):
        StateTuple = namedtuple("StateTuple", "base,flags")

        def make_node_tuple(node_line):
            """turn node,state line to (node, StateTuple(state))"""
            # state flags include: CLOUD, COMPLETING, DRAIN, FAIL, POWERED_DOWN,
            #   POWERING_DOWN
            node, fullstate = node_line.split(",")
            state = fullstate.split("+")
            state_tuple = StateTuple(state[0], set(state[1:]))
            return (node, state_tuple)

        cmd = (
            f"{self.scontrol} show nodes | "
            r"grep -oP '^NodeName=\K(\S+)|State=\K(\S+)' | "
            r"paste -sd',\n'"
        )
        node_lines = run(cmd, shell=True).stdout.rstrip().splitlines()
        nodes = {
            node: state
            for node, state in map(make_node_tuple, node_lines)
            if "CLOUD" in state.flags
        }
        return nodes

    def slurm_node(self, nodename):
        return self.slurm_nodes().get(nodename)

    def cloud_nodes(self):
        static_nodes = []
        dynamic_nodes = []

        for partition in lkp.cfg.partitions.values():
            part_name = partition.partition_name
            for node_group in partition.partition_nodes.values():
                static, dynamic = nodeset_lists(node_group, part_name)
                if static is not None:
                    static_nodes.extend(to_hostnames(static))
                if dynamic is not None:
                    dynamic_nodes.extend(to_hostnames(dynamic))

        return static_nodes, dynamic_nodes

    def filter_nodes(self, nodes):
        static_nodes, dynamic_nodes = lkp.cloud_nodes()

        all_cloud_nodes = []
        all_cloud_nodes.extend(static_nodes)
        all_cloud_nodes.extend(dynamic_nodes)

        cloud_nodes = list(set(nodes).intersection(all_cloud_nodes))
        local_nodes = list(set(nodes).difference(all_cloud_nodes))

        return cloud_nodes, local_nodes

    @lru_cache(maxsize=1)
    def instances(self, project=None, slurm_cluster_name=None):
        slurm_cluster_name = slurm_cluster_name or self.cfg.slurm_cluster_name
        project = project or self.project
        fields = (
            "items.zones.instances(name,zone,status,machineType,metadata),nextPageToken"
        )
        flt = f"labels.slurm_cluster_name={slurm_cluster_name} AND name:{slurm_cluster_name}-*"
        act = self.compute.instances()
        op = act.aggregatedList(project=project, fields=fields, filter=flt)

        def properties(inst):
            """change instance properties to a preferred format"""
            inst["zone"] = trim_self_link(inst["zone"])
            machine_link = inst["machineType"]
            inst["machineType"] = trim_self_link(machine_link)
            inst["machineTypeLink"] = machine_link
            # metadata is fetched as a dict of dicts like:
            # {'key': key, 'value': value}, kinda silly
            metadata = {i["key"]: i["value"] for i in inst["metadata"].get("items", [])}
            if "slurm_instance_role" not in metadata:
                return None
            inst["role"] = metadata["slurm_instance_role"]
            del inst["metadata"]  # no need to store all the metadata
            return NSDict(inst)

        instances = {}
        while op is not None:
            result = ensure_execute(op)
            instance_iter = (
                (inst["name"], properties(inst))
                for inst in chain.from_iterable(
                    m["instances"] for m in result["items"].values()
                )
            )
            instances.update(
                {name: props for name, props in instance_iter if props is not None}
            )
            op = act.aggregatedList_next(op, result)
        return instances

    def instance(self, instance_name, project=None, slurm_cluster_name=None):
        instances = self.instances(
            project=project, slurm_cluster_name=slurm_cluster_name
        )
        return instances.get(instance_name)

    def subscription(self, instance_name, project=None, slurm_cluster_name=None):
        subscriptions = self.subscriptions(
            project=project, slurm_cluster_name=slurm_cluster_name
        )
        subscriptions = [parse_self_link(s.name).subscription for s in subscriptions]
        return instance_name in subscriptions

    @lru_cache(maxsize=1)
    def machine_types(self, project=None):
        project = project or self.project
        field_names = "name,zone,guestCpus,memoryMb,accelerators"
        fields = f"items.zones.machineTypes({field_names}),nextPageToken"

        machines = defaultdict(dict)
        act = self.compute.machineTypes()
        op = act.aggregatedList(project=project, fields=fields)
        while op is not None:
            result = ensure_execute(op)
            machine_iter = chain.from_iterable(
                m["machineTypes"]
                for m in result["items"].values()
                if "machineTypes" in m
            )
            for machine in machine_iter:
                name = machine["name"]
                zone = machine["zone"]
                machines[name][zone] = machine

            op = act.aggregatedList_next(op, result)
        return machines

    def machine_type(self, machine_type, project=None, zone=None):
        """ """
        if zone:
            project = project or self.project
            machine_info = ensure_execute(
                self.compute.machineTypes().get(
                    project=project, zone=zone, machineType=machine_type
                )
            )
        else:
            machines = self.machine_types(project=project)
            machine_info = next(iter(machines[machine_type].values()), None)
            if machine_info is None:
                raise Exception(f"machine type {machine_type} not found")
        return NSDict(machine_info)

    def template_machine_conf(self, template_link, project=None, zone=None):

        template = self.template_info(template_link)
        if not template.machineType:
            temp_name = trim_self_link(template_link)
            raise Exception(f"instance template {temp_name} has no machine type")
        template.machine_info = self.machine_type(template.machineType, zone=zone)
        machine = template.machine_info

        machine_conf = NSDict()
        machine_conf.boards = 1  # No information, assume 1
        machine_conf.sockets = 1  # No information, assume 1
        # Each physical core is assumed to have two threads unless disabled or incapable
        _threads = template.advancedMachineFeatures.threadsPerCore
        _threads_per_core = _threads if _threads else 2
        _threads_per_core_div = 2 if _threads_per_core == 1 else 1
        machine_conf.threads_per_core = 1
        machine_conf.cpus = int(machine.guestCpus / _threads_per_core_div)
        machine_conf.cores_per_socket = int(machine_conf.cpus / machine_conf.sockets)
        # Because the actual memory on the host will be different than
        # what is configured (e.g. kernel will take it). From
        # experiments, about 16 MB per GB are used (plus about 400 MB
        # buffer for the first couple of GB's. Using 30 MB to be safe.
        gb = machine.memoryMb // 1024
        machine_conf.memory = machine.memoryMb - (400 + (30 * gb))
        return machine_conf

    @contextmanager
    def template_cache(self, writeback=False):
        flag = "c" if writeback else "r"
        err = None
        for wait in backoff_delay(0.125, cap=4, mul=2, max_count=20):
            try:
                cache = shelve.open(
                    str(self.template_cache_path), flag=flag, writeback=writeback
                )
                break
            except OSError as e:
                err = e
                log.debug(f"Failed to access template info cache: {e}")
                sleep(wait)
                continue
        else:
            # reached max_count of waits
            raise Exception(f"Failed to access cache file. latest error: {err}")
        try:
            yield cache
        finally:
            cache.close()

    @lru_cache(maxsize=None)
    def template_info(self, template_link, project=None):

        project = project or self.project
        template_name = trim_self_link(template_link)
        # split read and write access to minimize write-lock. This might be a
        # bit slower? TODO measure
        if self.template_cache_path.exists():
            with self.template_cache() as cache:
                if template_name in cache:
                    return NSDict(cache[template_name])

        template = ensure_execute(
            self.compute.instanceTemplates().get(
                project=project, instanceTemplate=template_name
            )
        ).get("properties")
        template = NSDict(template)
        # name and link are not in properties, so stick them in
        template.name = template_name
        template.link = template_link
        # TODO delete metadata to reduce memory footprint?
        # del template.metadata

        # translate gpus into an easier-to-read format
        if template.guestAccelerators:
            template.gpu_type = template.guestAccelerators[0].acceleratorType
            template.gpu_count = template.guestAccelerators[0].acceleratorCount
        else:
            template.gpu_type = None
            template.gpu_count = 0

        # keep write access open for minimum time
        with self.template_cache(writeback=True) as cache:
            cache[template_name] = template.to_dict()
        # cache should be owned by slurm
        chown_slurm(self.template_cache_path)

        return template

    @lru_cache(maxsize=1)
    def subscriptions(self, project=None, slurm_cluster_name=None):
        return subscription_list(
            project_id=project, slurm_cluster_name=slurm_cluster_name
        )

    def clear_template_info_cache(self):
        with self.template_cache(writeback=True) as cache:
            cache.clear()
        self.template_info.cache_clear()


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
