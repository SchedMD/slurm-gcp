#!/usr/bin/env python3
import inspect
import logging
import shutil
import sys
import yaml
from pathlib import Path
from subprocess import DEVNULL

script = Path(inspect.getfile(inspect.currentframe())).resolve()
sys.path.insert(0, str(script.parent.parent))

from util import run, get_metadata, config_root_logger, NSDict, cd

config_root_logger()
log = logging.getLogger(script.name)

metakey = 'external-slurm-install'
metadata = get_metadata(f'attributes/{metakey}')
if not metadata:
    sys.exit()

mount = NSDict(yaml.safe_load(metadata))
log.debug(f"external mount: {mount}")

prefix = Path(mount.mount)
prefix.mkdir(parents=True, exist_ok=True)
run(f"mount -t {mount.type} {mount.remote} {mount.mount}", check=True)

srcdir = next(filter(Path.is_dir,
                     Path('/usr/local/src/slurm').glob('slurm-*')))
builddir = Path('/tmp/build/slurm')
builddir.mkdir(parents=True, exist_ok=True)
with cd(builddir):
    run(f"{srcdir}/configure --prefix={mount.mount} --with-jwt=/usr/local --sysconfdir=/usr/local/etc/slurm",
        stdout=DEVNULL, check=True)
    run("make -j install", stdout=DEVNULL, check=True)
    with cd('contribs'):
        run("make -j install", stdout=DEVNULL, check=True)

# tpu instance needs slurmd.service
(prefix/'etc').mkdir(parents=True, exist_ok=True)
shutil.copy(builddir/'etc/slurmd.service', prefix/'etc/slurmd.service')
