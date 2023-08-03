#!/usr/bin/env python3

# Copyright (C) SchedMD LLC.
# Copyright 2015 Google Inc. All rights reserved.
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
import subprocess
import shlex
import tempfile
import os
import json
import yaml


def run(
    args,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    shell=False,
    timeout=None,
    check=True,
    universal_newlines=True,
    **kwargs,
):
    """Wrapper for subprocess.run() with convenient defaults"""
    if isinstance(args, list):
        args = list(filter(lambda x: x is not None, args))
        args = " ".join(args)
    if not shell and isinstance(args, str):
        args = shlex.split(args)
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


def dict_to_conf(conf, delim=" "):
    """convert dict to delimited slurm-style key-value pairs"""

    def filter_conf(pair):
        k, v = pair
        if isinstance(v, list):
            v = ",".join(el for el in v if el is not None)
        return k, (v if bool(v) or v == 0 else None)

    return delim.join(
        f'{k} = "{v}"' for k, v in map(filter_conf, conf.items()) if v is not None
    )


def calculate_python310(tf_version):
    (major, minor, patch) = tf_version.split(".")

    python310 = int(major) >= 2 and (
        int(minor) >= 13 or (int(minor) == 12 and int(patch) >= 1)
    )
    return python310


def print_exception(e):
    print(f"process {e.cmd} failed with exitcode {e.returncode}")
    print(f"stdout: \n=================\n{e.stdout}")
    print(f"stderr: \n=================\n{e.stdout}")
    exit(e.returncode)


def get_tf_versions(yaml_file_path):
    with open(yaml_file_path, "r") as file:
        try:
            yaml_data = yaml.safe_load(file)
        except yaml.YAMLError as exc:
            print(f"Error while parsing YAML file({yaml_file_path}):", exc)
            return None
    return list(yaml_data["tf_versions_to_tpu_mapping"].keys())


parser = argparse.ArgumentParser(
    description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
)
parser.add_argument(
    "--project_id",
    "-p",
    dest="project_id",
    default="schedmd-slurm-public",
    help="The project id to use for pushing the docker images.",
)
parser.add_argument(
    "--slurm_version",
    "-s",
    dest="slurm_version",
    default="23.02.4",
    help="The Slurm version to use for the image.",
)
parser.add_argument(
    "--gcp_version",
    "-g",
    dest="slurmgcp_version",
    default="6.1.0",
    help="The slurm_gcp version to use for the image.",
)
# TODO Get the default from ansible tpu role
parser.add_argument(
    "-t",
    "--tf_versions",
    nargs="+",
    default=[],
    help="The tf_versions to use",
)
parser.add_argument(
    "-d",
    "--docker_push",
    help="set this flag to automatically push the images with docker",
    action="store_true",
)

os.chdir(os.path.dirname(os.path.abspath(__file__)))

args = parser.parse_args()

all_tf_versions = get_tf_versions("../../ansible/roles/tpu/vars/main.yml")
if not args.tf_versions:
    args.tf_versions = all_tf_versions
else:
    if not set(args.tf_versions).issubset(set(all_tf_versions)):
        print(
            f"Argument tf_versions list {args.tf_versions} is not a valid subset of the supported tf_versions {all_tf_versions}"
        )
        exit(1)

file_params = {
    "install_lustre": "false",
    "source_image_project_id": "irrelevant",
    "zone": "irrelevant",
    "tf_version": "overriden",
}
file_params["project_id"] = args.project_id
file_params["slurm_version"] = args.slurm_version
file_params["slurmgcp_version"] = args.slurmgcp_version

data = dict_to_conf(file_params, delim="\n") + "\n"

tmp_file = tempfile.NamedTemporaryFile(mode="w+t", delete=False, suffix=".pkvars.hcl")
tmp_file.write(data)
tmp_file.close()

dock_build_data = {}
base_images = []
for tf_version in args.tf_versions:
    docker_image = "ubuntu:22.04" if calculate_python310(tf_version) else "ubuntu:20.04"
    if docker_image not in base_images:
        base_images.append(docker_image)
    dock_build_data[tf_version] = docker_image

for base_image in base_images:
    print(f"Building base_image {base_image}")
    try:
        run(
            f'packer build -var-file={tmp_file.name} -var "docker_image={base_image}" -only "base.*" .'
        )
    except subprocess.CalledProcessError as e:
        print_exception(e)
        exit(e.returncode)

for tf_version, docker_image in dock_build_data.items():
    print(f"Build tf image {tf_version} using base_image {docker_image}")
    try:
        run(
            f'packer build -var-file={tmp_file.name} -var "docker_image={docker_image}" -var "tf_version={tf_version}" -only "tensorflow.*" .'
        )
    except subprocess.CalledProcessError as e:
        print_exception(e)
        print("Skipping to next tf_version")
        continue
    if args.docker_push:
        image_name = None
        with open("docker-manifest.json", "r") as f:
            data = json.load(f)
            image_name = data["builds"][0]["artifact_id"]
        if image_name:
            print("Pushing the image")
            try:
                run(f"docker push {image_name}")
            except subprocess.CalledProcessError as e:
                print_exception(e)
                print("Skipping to next tf_version")
                continue
        else:
            print(
                f"Error retrieving the docker image name for docker_image={docker_image} tf_version={tf_version}"
            )
os.remove(tmp_file.name)
