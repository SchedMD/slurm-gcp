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

import argparse
import logging
import shlex
import subprocess as sp
import time
import yaml
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

from googleapiclient import discovery


log = logging
logging.basicConfig(level=logging.INFO, format='')


def run(cmd, wait=0, quiet=False, get_stdout=False,
        shell=False, universal_newlines=True, **kwargs):
    """ run in subprocess. Optional wait after return. """
    if not quiet:
        log.info(f"run: {cmd}")
    if get_stdout:
        kwargs['stdout'] = sp.PIPE

    args = cmd if shell else shlex.split(cmd)
    ret = sp.run(args, shell=shell, universal_newlines=universal_newlines,
                 **kwargs)
    if wait:
        time.sleep(wait)
    return ret


def gcloud_dm(cmd, *args, **kwargs):
    return run(f"gcloud deployment-manager {cmd}", *args, **kwargs)


project = run("gcloud config list --format='value(core.project)'",
              get_stdout=True, quiet=True).stdout.rstrip()


def wait_for_stop(instance, zone, timeout=30):
    """ Wait for instance to stop, timeout in minutes """
    compute = discovery.build('compute', 'v1', cache_discovery=False)
    log.info(f"waiting for {instance} to stop")
    interval = 10
    attempts = (timeout * 60) // interval
    while True:
        resp = compute.instances().get(
            project=project,
            zone=zone,
            fields='status',
            instance=instance).execute()
        if resp['status'] == 'TERMINATED':
            break
        time.sleep(interval)
        attempts -= 1
        if attempts <= 0:
            log.info(f"Timed out waiting for instance to stop: {instance}")
            return False
    return True


def create_images(instances):
    tag = "{:%Y-%m-%d-%H%M%S}".format(datetime.now(timezone.utc))
    
    def create_image(instance, image_name, zone):
        log.info(f"... waiting to create image for {instance}")
        if not wait_for_stop(instance, zone):
            return False
        image_name = image_name.format(tag=tag)
        try:
            run(f"gcloud compute images create {image_name} --source-disk {instance}"
                f" --source-disk-zone {zone} --force --family {instance} --quiet",
                check=True)
        except sp.CalledProcessError:
            return False
        return True

    with ThreadPoolExecutor() as exe:
        results = exe.map(lambda inst: create_image(**inst), instances.values())
    # return True if all images successfully created
    return all(results)


def read_instances(dep_name):
    """ Get instances from the deployment """
    res = gcloud_dm("resources list "
                    f"--deployment={dep_name} "
                    "--filter='type=compute.v1.instance' "
                    "--format='yaml(name,properties)'",
                    get_stdout=True, check=True).stdout

    # load all the properties from the yaml text it comes as
    instance_list = [
        {
            'name': inst['name'],
            'properties': yaml.safe_load(inst['properties']),
        } for inst in yaml.safe_load_all(res)
    ]
    # get zone and image_name from properties
    # getting from metadata requires a search because it's a list of key-value
    # pairs
    instances = {
        el['name']: dict(
            instance=el['name'],
            image_name=next(m for m in el['properties']['metadata']['items']
                            if m['key'] == 'image_name')['value'],
            zone=el['properties']['zone'],
        ) for el in instance_list
    }
    log.info(
        '\n'.join("{instance}: {zone}, {image_name}".format(**inst)
                  for inst in instances.values()),
    )
    return instances


def main(dep_name='slurm-image-foundry', cleanup=True, force=False,
         resume=False, pause=False):

    existing = gcloud_dm("deployments list "
                         f"--filter='name ~ ^{dep_name}$' "
                         "--format='value(name)'",
                         get_stdout=True, check=True).stdout
    if existing:
        log.info(f"{dep_name} deployment found,")
        if resume:
            log.info("\tresuming image creation")
        elif force:
            log.info("\tdeleting")
            gcloud_dm(f"\tdeployments delete {dep_name}", check=True)
        else:
            log.info("\taborting")
            return
    elif resume:
        log.error(f"{dep_name} deployment not found, cannot resume")
        return

    if not resume:
        glob_enabled = run("gcloud config get-value deployment_manager/glob_imports",
                           get_stdout=True).stdout.strip() == "True"
        if not glob_enabled:
            run("gcloud config set deployment_manager/glob_imports True")
        gcloud_dm(f"deployments create {dep_name} --config slurm-cluster.yaml")
        if not glob_enabled:
            run("gcloud config set deployment_manager/glob_imports False")

    instances = read_instances(dep_name)

    if pause:
        with ThreadPoolExecutor() as exe:
            exe.map(lambda inst: wait_for_stop(inst['instance'], inst['zone']),
                    instances.values())
        return

    if create_images(instances) and cleanup:
        gcloud_dm(f"deployments delete {dep_name}", check=True)


OPTIONS = (
    ('dep_name',
     dict(metavar='deployment', action='store', nargs='?', default='slurm-image-foundry',
          help="Name of the deployment to be created to manage the foundry instances")),
    ('--force', '-f',
     dict(dest='force', action='store_true',
          help="delete existing deployments of the same name first")),
    ('--no-cleanup', '-c',
     dict(dest='cleanup', action='store_false',
          help="Do not delete the deployment at the end. By default, the deployment is deleted if all images were successfully created")),
    ('--resume', '-r',
     dict(dest='resume', action='store_true',
          help="Create images from whatever instances are in the existing deployment")),
    ('--pause', '-p',
     dict(dest='pause', action='store_true',
          help="Do not create images from the instances to allow for customizations")),
)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description="Slurm Image Foundry"
    )
    for x in OPTIONS:
        parser.add_argument(*x[:-1], **x[-1])
    args = parser.parse_args()
    if args.force and args.resume:
        log.error("Invalid options")
        exit(1)
    if args.resume and args.pause:
        log.erro("Invalid options")
        exit(1)
    if args.pause and args.cleanup:
        log.info("pause requires no-cleanup")
        args.cleanup = False
    main(**vars(args))
