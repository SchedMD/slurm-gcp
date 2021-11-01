#!/usr/bin/env bash
set -e
script=/slurm/scripts/clustersync.py
exec /usr/local/bin/python $script "$@"
