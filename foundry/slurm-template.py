#!/usr/bin/env python
# Copyright 2020 SchedMD LLC.
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

import yaml
import io
import zipfile as zf
import base64
import re


def compress(name, text):
    buf = io.BytesIO()
    with zf.ZipFile(buf, 'w', zf.ZIP_DEFLATED) as f:
        f.writestr(name, text)
    return base64.b64encode(buf.getvalue())


vm_yaml = """
name: {name}
type: compute.v1.instance
properties:
  zone: {zone}
  machineType: {machine_type}
  disks:
  - deviceName: boot
    type: PERSISTENT
    boot: true
    autoDelete: true
    initializeParams:
      sourceImage: {image}
      diskSizeGb: 20
  networkInterfaces:
  - network: global/networks/default
    accessConfigs:
    - name: External NAT
      type: ONE_TO_ONE_NAT
  serviceAccounts:
  - email: default
    scopes: ['https://www.googleapis.com/auth/cloud-platform']
  scheduling:
    onHostMaintenance: TERMINATE
  labels: {{}}
  metadata:
    items: []
"""

meta_imports = {
    'startup-script': 'scripts/startup.sh',
    'util-script': 'scripts/util.py',
    'setup-script': 'scripts/setup.py',
    'ops-agent-yaml': 'etc/ops_agent.yaml',
}


def generate_config(context):
    """
    For a given OS image, create a controller, compute, and login instance
    """
    props = context.properties

    image_specs = {
        im['base']: im
        for im in props['images']
    }
    meta = {k: context.imports[v] for k, v in meta_imports.items()}
    meta['enable-oslogin'] = 'TRUE'
    meta['libjwt_version'] = props['libjwt_version']
    meta['ompi_version'] = props['ompi_version']

    meta['slurm_version'] = slurm_version = str(props['slurm_version'])
    version_patt = re.compile(
        r"^(b\:(?P<branch>[\w\-\.]+))|((?P<major>\d{2}\.\d{2})[\.\-](?P<minor>(?<=\.)\d+|(?<=\-)latest(?=$))(-(?P<micro>\d+))?)$")
    # the micro-version (micro) is not included in the image or family name
    m = version_patt.match(slurm_version)
    if m is None:
        raise Exception("Invalid slurm_version")
    slurm_version = m.groupdict()

    for path in filter(lambda x: x.startswith('custom.d/'),
                       context.imports.keys()):
        new = path.replace('custom.d/', 'custom-')
        new = new.replace('.', '_')
        meta[new] = context.imports[path]
    # 'VmDnsSetting': 'GlobalOnly',

    resources = []

    for base, spec in image_specs.items():
        image = spec['base_image']
        zone = props['zone']
        machine_type = props['machine_type']

        # Use provided name formats to determine image name and family
        if 'major' in slurm_version:
            keywords = {
                'base': base,
                'major': '-'.join(slurm_version['major'].split('.')),
                'minor': slurm_version['minor'],
                'micro': slurm_version['micro'] if 'micro' in slurm_version else "",
                'tag': '{tag}',
            }
        else:
            keywords = {
                'base': base,
                'major': 'b',
                'minor': '-'.join(slurm_version['branch'].split('.')),
                'micro': "",
                'tag': '{tag}',
            }
        family_format = spec['family'] or props['image_family']
        name_format = spec['name'] or props['image_name']

        image_family = family_format.format(**keywords)
        keywords['image_family'] = image_family
        image_name = name_format.format(**keywords)
        meta['image_name'] = image_name

        packages = spec['packages'] or f'scripts/{base}-packages'
        meta['packages'] = context.imports[packages]

        # Insert properties into yaml for conversion to resources dict
        vm_config = {
            'name': image_family,
            'machine_type': "zones/{zone}/machineTypes/{machine_type}".format(
                zone=zone, machine_type=machine_type),
            'zone': props['zone'],
            'image': image,
        }

        res = yaml.safe_load(vm_yaml.format(**vm_config))

        # Insert metadata directly into resources dict
        res['properties']['metadata']['items'] = (
            [dict(key=k, value=v) for k, v in meta.items()])
        resources.append(res)

    return {'resources': resources}
