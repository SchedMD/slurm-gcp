#!/usr/bin/env python3
# Copyright 2021 SchedMD LLC.
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

import shlex
import subprocess
import sys
import time

def run(cmd, wait=0, quiet=False, get_stdout=False,
        shell=False, universal_newlines=True, **kwargs):
    """ run in subprocess. Optional wait after return. """
    if not quiet:
        print(cmd)
    if get_stdout:
        kwargs['stdout'] = subprocess.PIPE

    args = cmd if shell else shlex.split(cmd)
    ret = subprocess.run(args, shell=shell,
                         universal_newlines=universal_newlines,
                         **kwargs)
    if wait:
        time.sleep(wait)
    return ret

def main():
    output = run(f"terraform output -no-color cluster_name", shell=True, check=True, get_stdout=True).stdout

    if "Warning: No outputs found" in output:
        print("No outputs in tfstate. Aborting removal process.")
        sys.exit(0)

    print("Attempting to removal compute nodes to 'tfstate'...")
    cluster_name = output.strip()
    compute_list = run(f"gcloud compute instances list --uri --filter='tags.items={cluster_name} AND tags.items=\"compute\" AND tags.items=\"dynamic\"'", shell=True, check=True, get_stdout=True).stdout.strip().split('\n')
    if len(compute_list) == 0 or compute_list[0] == '':
        print(f"No compute nodes found for cluster {cluster_name}. Aborting removal process.")
        sys.exit(0)

    for compute_uri in compute_list:
        compute_name = compute_uri.strip().split('/')[-1]
        run(f"terraform state rm 'module.slurm_cluster_compute.google_compute_instance.compute_node[\"{compute_name}\"]'")
    print("done.")

if __name__ == '__main__':
    main()
