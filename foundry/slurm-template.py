#!/usr/bin/env python
import yaml
import io
import zipfile as zf
import base64
from datetime import datetime, timezone


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
  serviceAccounts:
  - email: default
    scopes: ['https://www.googleapis.com/auth/cloud-platform']
  labels: {{}}
  metadata:
    items: []
"""

router_yaml = """
name: {name}
type: compute.v1.router
properties:
  network: https://www.googleapis.com/compute/v1/projects/{project}/global/networks/default
  region: {region}
  nats:
  - name: {nat_name}
    natIpAllocateOption: "AUTO_ONLY"
    sourceSubnetworkIpRangesToNat: "LIST_OF_SUBNETWORKS"
    subnetworks:
    - name: https://www.googleapis.com/compute/v1/projects/{project}/regions/{region}/subnetworks/default
      SourceIpRangesToNat: ["PRIMARY_IP_RANGE"]
"""


meta_imports = {
    'startup-script': 'scripts/startup.sh',
    'util-script': 'scripts/util.py',
    'setup-script': 'scripts/setup.py',
    'fluentd-conf': 'etc/fluentd.conf',
}


def generate_config(context):
    """
    For a given OS image, create a controller, compute, and login instance
    """
    props = context.properties

    dep_name = context.env['name']
    project = context.env['project']
    image_specs = {
        im['base']: im
        for im in props['images']
    }
    meta = {k: context.imports[v] for k, v in meta_imports.items()}
    meta['enable-oslogin'] = 'TRUE'
    meta['libjwt_version'] = props['libjwt_version']
    meta['ompi_version'] = props['ompi_version']
    meta['slurm_version'] = slurm_version = props['slurm_version']
    # 'VmDnsSetting': 'GlobalOnly',

    resources = []
    router = router_yaml.format(**{
        'name': '{}-router'.format(dep_name),
        'project': project,
        'region': '-'.join(props['zone'].split('-')[:-1]),
        'nat_name': '{}-nat'.format(dep_name),
    })
    resources.append(yaml.safe_load(router))

    for base, spec in image_specs.items():
        image = spec['base_image']
        zone = props['zone']
        machine_type = props['machine_type']

        # Use provided name formats to determine image name and family
        keywords = {
            'base': base,
            'major': ''.join(slurm_version.split('.')[:2]),
            'minor': slurm_version.replace('.', ''),
            'tag': "{:%Y-%m-%d-%H%M%S}".format(datetime.now(timezone.utc)),
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
            'machine_type': f"zones/{zone]}/machineTypes/{machine_type}",
            'zone': props['zone'],
            'image': image,
        }

        res = yaml.safe_load(vm_yaml.format(**vm_config))

        # Insert metadata directly into resources dict
        res['properties']['metadata']['items'] = (
            [dict(key=k, value=v) for k, v in meta.items()])
        resources.append(res)

    return {'resources': resources}
