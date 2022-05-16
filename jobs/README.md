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

## submit_workflow.py

This script is a runner that submits a sequence of 3 jobs as defined in the
input structured yaml file. The three jobs submitted can be refered to as:
`stage_in`; `main`; and `stage_out`. `stage_in` should move data for `main` to
consume. `main` is the main script that may consume and generate data.
`stage_out` should move data generated from `main` to an external location.

Example usage:

```sh
$ /slurm/jobs/submit_workflow.py /slurm/jobs/shuffle.yaml
```

For your specific workload, prepare `stage_in` and `stage_out` scripts for your
desired `main` job. Configure a workflow yaml and submit it with the
`submit_workflow.py` runner.

### shuffle.yaml

This is a structured yaml file which defines a sequence of jobs to be submitted.
The sample configuration copies an arbitrary multiline file from a GCP bucket to
`$HOME`. An output file is generated from the main script and the input file,
which is copied to an arbitrary location (another GCP bucket).

**Warning:** This workflow yaml will fail unless the defined GCP buckets and
input file exist.
