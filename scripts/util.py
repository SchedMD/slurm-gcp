#!/usr/bin/env python3

import yaml
import requests
from pathlib import Path


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

def get_pid(node_name):
    """Convert <prefix>-<pid>-<nid>"""

    return int(node_name.split('-')[-2])

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
                   'vpc_subnet',
                   'shared_vpc_host_proj',
                   'compute_node_service_account',
                   'compute_node_scopes',
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
                  'controller_secondary_disk',
                  'suspend_time',
                  'login_node_count',
                  )

    def __init__(self, properties):
        # Add all properties to object namespace
        [setattr(self, k, v) for k, v in properties.items()]

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
