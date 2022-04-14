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


import argparse
from pathlib import Path
import subprocess
import yaml


def dict_to_kv(dict):
    """convert dict to space-delimited slurm-style key-value pairs"""
    return ",".join(
        f"{k}={','.join(v) if isinstance(v, list) else v}"
        for k, v in dict.items()
        if v is not None
    )


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


def main(config):
    try:
        env = dict_to_kv(config["stage_in"]["environment"])
    except Exception:
        env = ""
    script = config["stage_in"]["script"]
    cmd = f"sbatch --parsable --export=ALL,{env} {script}"
    job_id_stage_in = run(cmd, shell=True).stdout.strip()
    print(f"stage_in : JobId={job_id_stage_in}")

    try:
        env = dict_to_kv(config["main"]["environment"])
    except Exception:
        env = ""
    script = config["main"]["script"]
    cmd = f"sbatch --parsable --export=ALL,{env} --dependency=afterok:{job_id_stage_in} {script}"
    job_id_main = run(cmd, shell=True).stdout.strip()
    print(f"main : JobId={job_id_main}")

    try:
        env = dict_to_kv(config["stage_out"]["environment"])
    except Exception:
        env = ""
    script = config["stage_out"]["script"]
    cmd = f"sbatch --parsable --export=ALL,{env} --dependency=afterok:{job_id_main} {script}"
    job_id_stage_out = run(cmd, shell=True).stdout.strip()
    print(f"stage_out : JobId={job_id_stage_out}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Submits data migration workflow based on yaml."
    )
    parser.add_argument("config", type=Path, help="yaml configuration")

    args = parser.parse_args()

    config = yaml.safe_load(open(args.config))

    main(config)
