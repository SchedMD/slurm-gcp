#!/usr/bin/env python

import logging
import re
import shlex
import subprocess as sp
import sys
import time
import yaml
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

from googleapiclient import discovery


log = logging
logging.basicConfig(level=logging.INFO)


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


project = run("gcloud config list --format='value(core.project)'",
              get_stdout=True, quiet=True).stdout.rstrip()


def create_images(instances):
    
    def create_image(instance, zone):
        log.info(f"... waiting to create image for {instance}")
        compute = discovery.build('compute', 'v1', cache_discovery=False)
        attempts = 0
        while True:
            resp = compute.instances().get(
                project=project,
                zone=zone,
                fields='status',
                instance=instance).execute()
            if resp['status'] == 'TERMINATED':
                break
            time.sleep(15)
            attempts += 1
            if attempts > 120:
                print(f"Timed out waiting for instance to stop: {instance}")
                return False
        gimages = "gcloud compute images"
        ver = datetime.now(timezone.utc)
        try:
            run(f"{gimages} create {instance}-{ver:%Y-%m-%d-%H%M%S} --source-disk {instance}"
                f" --source-disk-zone {zone} --force --family {instance} --quiet", check=True)
            #run(f"gcloud compute instances delete {instance} --zone {zone} --quiet", check=True)
        except sp.CalledProcessError:
            return False
        return True

    with ThreadPoolExecutor() as exe:
        results = exe.map(lambda it: create_image(*it), instances.items())
    # return True if all images successfully created
    return all(results)


def main(dep_name='slurm-image-foundry'):

    depman = "gcloud deployment-manager"
    run(f"{depman} deployments create {dep_name} --config slurm-cluster.yaml")

    res = run(f"{depman} resources list --deployment={dep_name} --format='yaml(name,type,url)'",
              get_stdout=True)
    # extract zone from resource url
    zone_patt = re.compile(r'^https:.+zones\/(.+?)\/.+$')
    instance_list = yaml.safe_load_all(res.stdout)
    print(instance_list)
    instances = {el['name']: zone_patt.match(el['url'])[1] for el in instance_list
                 if el['type'].endswith('instance')}
    print(instances)
    if create_images(instances):
        run(f"{depman} deployments remove {dep_name}")


if __name__ == '__main__':
    name = sys.argv[1] if len(sys.argv) > 1 else None
    if name:
        main(name)
    else:
        main()
