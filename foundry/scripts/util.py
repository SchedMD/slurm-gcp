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


log = logging.getLogger(__name__)


def config_root_logger(level='DEBUG', util_level=None, stdout=True, file=None):
    if not util_level:
        util_level = level
    handlers = []
    if file:
        handlers.append('file_handler')
    if stdout or not file:
        handlers.append('stdout_handler')
    config = {
        'version': 1,
        'disable_existing_loggers': True,
        'formatters': {
            'standard': {
                'format': '%(funcName)s %(levelname)s: %(message)s',
            },
            'stamp': {
                'format': '%(asctime)s %(funcName)s %(levelname)s: %(message)s',
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
                'handlers': handlers,
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
        log.debug(f"{cmd}")
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


@contextmanager
def cd(path):
    """ Change working directory for context """
    prev = Path.cwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(prev)


class cached_property:
    """
    Decorator for creating a property that is computed once and cached
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
    def __init__(self, *args, **kwargs):
        def from_nested(value):
            """ If value is dict, convert to NSDict. Also recurse lists. """
            if isinstance(value, dict):
                return NSDict({k: from_nested(v) for k, v in value.items()})
            elif isinstance(value, list):
                return [from_nested(v) for v in value]
            else:
                return value
        
        super(NSDict, self).__init__(*args, **kwargs)
        self.__dict__ = self  # all properties are member attributes

        # Convert nested dicts
        for k, v in self.items():
            self[k] = from_nested(v)
