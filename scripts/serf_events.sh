#!/usr/bin/env bash
set -e
script=/slurm/scripts/serf_events.py
exec /usr/local/bin/python $script "$@"
