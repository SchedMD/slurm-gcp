#!/usr/bin/env python
import yaml
import io
import zipfile as zf
import base64


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
    os_images = {
        im['name']:
            (im['image'], str(im.get('slurm_version', props['slurm_version'])))
        for im in props['images']
    }
    meta = {k: context.imports[v] for k, v in meta_imports.items()}
    meta['enable-oslogin'] = 'TRUE'
    # 'VmDnsSetting': 'GlobalOnly',

    resources = []
    router = router_yaml.format(**{
        'name': '{}-router'.format(dep_name),
        'project': project,
        'region': '-'.join(props['zone'].split('-')[:-1]),
        'nat_name': '{}-nat'.format(dep_name),
    })
    resources.append(yaml.safe_load(router))

    for os_name, (image, slurm_version) in os_images.items():
        # Insert properties into yaml for conversion to resources dict
        vm_config = {
            'name': 'schedmd-slurm{vers}-{os_name}'.format(
                os_name=os_name,
                vers=slurm_version.replace('.', '')),
            'machine_type': props['machine_type'],
            'zone': props['zone'],
            'image': image,
        }

        res = yaml.safe_load(vm_yaml.format(**vm_config))
        # meta['config'] = yaml.safe_dump(res)

        meta['packages'] = context.imports['scripts/{os_name}-packages'.format(os_name=os_name)]
        meta['slurm_version'] = slurm_version

        # Insert metadata directly into resources dict
        res['properties']['metadata']['items'] = (
            [dict(key=k, value=v) for k, v in meta.items()])
        resources.append(res)

    return {'resources': resources}
