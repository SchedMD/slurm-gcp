# Jobs

This directory contains sample jobs for different purposes.

## shuffle.sh

This job shuffles lines of the input file into a random order. A simple job that
generates output and is easy to verify.

It is intended to be used by `data_migrate.py` workflow.

```sh
$ seq 10 > /tmp/seq.txt
$ sbatch --export=MIGRATE_INPUT=/tmp/seq.txt,MIGRATE_OUTPUT=/tmp/shuffle.txt \
	/slurm/jobs/shuffle.sh
```

## data_migrate.py

This script is a sample workflow for data migration using
[**gsutil**](https://cloud.google.com/storage/docs/gsutil). It will create three
jobs derived from the input configuration yaml file. Simply the stage_in job
moves data from an external source to a filesystem that a node can read from.
Then the main job runs, typically consuming that moved data. After, the
stage_out runs to move data from the compute node to an external destination.

It is quite simple to modify for your use. Copy it and fill in the yaml with
your configuration. Try it out!

```sh
$ /slurm/jobs/data_migrate.py /slurm/jobs/data_migrate.yaml
```
