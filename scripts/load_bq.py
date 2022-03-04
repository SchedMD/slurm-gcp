#!/usr/bin/env python3

import argparse
import os
import sys
import json
from collections import namedtuple
from datetime import datetime, timedelta, timezone
from pathlib import Path

from addict import Dict as NSDict
from google.cloud.bigquery import SchemaField
from google.cloud import bigquery as bq
from google.api_core import retry, exceptions

import util
from util import run
from util import cfg, lkp, compute
from util import def_creds


SACCT = "sacct"
script = Path(__file__).resolve()
DEFAULT_TIMESTAMP_FILE = script.parent / "bq_timestamp"
timestamp_file = os.environ.get("TIMESTAMP_FILE") or DEFAULT_TIMESTAMP_FILE


def make_datetime(timestamp):
    return datetime.fromtimestamp(timestamp, tz=timezone.utc)


def make_time_interval(seconds):
    sign = 1
    if seconds < 0:
        sign = -1
        seconds = abs(seconds)
    d, r = divmod(seconds, 60 * 60 * 24)
    h, r = divmod(r, 60 * 60)
    m, s = divmod(r, 60)
    d *= sign
    h *= sign
    return f"{d}D {h:02}:{m:02}:{s}"


converters = {
    "DATETIME": make_datetime,
    "INTERVAL": make_time_interval,
    "STRING": str,
    "INT64": int,
}


def schema_field(slurm_name, schema_name, data_type, description, required=False):
    return (
        slurm_name,
        SchemaField(
            schema_name,
            data_type,
            description=description,
            mode="REQUIRED" if required else "NULLABLE",
        ),
    )


schema_fields_def = [
    (
        "JobIDRaw",
        "job_id_raw",
        "INT64",
        "raw job id",
        True,
    ),
    ("JobID", "job_id", "STRING", "job id", True),
    ("State", "state", "STRING", "final job state", True),
    ("JobName", "job_name", "STRING", "job name"),
    ("Partition", "partition", "STRING", "job partition"),
    ("Submit", "submit_time", "DATETIME", "job submit time"),
    ("Start", "start_time", "DATETIME", "job start time"),
    ("End", "end_time", "DATETIME", "job end time"),
    ("ElapsedRaw", "elapsed_raw", "INT64", "STRING", "job run time in seconds"),
    # ("Elapsed", "elapsed_time", "INTERVAL", "STRING", "job run time interval"),
    ("TimelimitRaw", "timelimit_raw", "STRING", "job timelimit in minutes"),
    ("Timelimit", "timelimit", "STRING", "job timelimit"),
    ("NNodes", "num_nodes", "INT64", "number of nodes in job"),
    ("NTasks", "num_tasks", "INT64", "number of tasks in job"),
    ("Nodelist", "nodelist", "STRING", "nodes allocated to job"),
    ("User", "user", "STRING", "user responsible for job"),
    ("Uid", "uid", "INT64", "uid of job user"),
    ("Group", "group", "STRING", "group of job user"),
    ("Gid", "gid", "INT64", "gid of job user"),
    ("Wckey", "wckey", "STRING", "job wckey"),
    ("Qos", "qos", "STRING", "job qos"),
    ("Comment", "comment", "STRING", "job comment"),
    ("ExitCode", "exitcode", "STRING", "job exit code"),
    ("AllocCPUs", "alloc_cpus", "INT64", "count of allocated CPUs"),
    ("AllocNodes", "alloc_nodes", "INT64", "number of nodes allocated to job"),
    ("AllocTres", "alloc_tres", "STRING", "allocated trackable resources (TRES)"),
    # ("SystemCPU", "system_cpu", "INTERVAL", "cpu time used by parent processes"),
    # ("CPUTime", "cpu_time", "INTERVAL", "CPU time used (elapsed * cpu count)"),
    ("CPUTimeRaw", "cpu_time_raw", "INT64", "CPU time used (elapsed * cpu count)"),
    ("AveCPU", "avecpu", "INT64", "Average CPU time of all tasks in job"),
    (
        "TresUsageInTot",
        "tres_usage_tot",
        "STRING",
        "Tres total usage by all tasks in job",
    ),
]

# slurm field name is the key for schema_fields
schema_fields = dict(schema_field(field) for field in schema_fields_def)
# new field name is the key for job_schema. Used to lookup the datatype when
# creating the job rows
job_schema = {field.name: field for field in schema_fields.values()}
# Order is important here, as that is how they are parsed from sacct output
Job = namedtuple("Job", job_schema.keys())

client = bq.Client(project=cfg.project, credentials=def_creds)
dataset_id = f"{cfg.slurm_cluster_name}_job_data"
dataset = bq.DatasetReference(project=cfg.project, dataset_id=dataset_id)
table = bq.Table(
    bq.TableReference(dataset, f"{cfg.slurm_cluster_name}_jobs"), job_schema.values()
)


class JobInsertionFailed(Exception):
    pass


def make_job_row(job):
    job_row = {
        field: dict.get(converters, job_schema[field])(value)
        for field, value in job._asdict().items()
    }
    return job_row


def load_slurm_jobs(start, end):
    start_iso = start.isoformat(timespec="seconds")
    end_iso = end.isoformat(timespec="seconds")
    fields = ",".join(schema_fields.keys())
    cmd = f"{SACCT} --start {start_iso} --end {end_iso} -X -D --format={fields} --parsable2 --noheader"
    text = run(cmd).stdout.splitlines
    jobs = [Job(*line.split("|")) for line in text[1:]]

    job_rows = [
        make_job_row(job) for job in jobs if job.state not in ("PENDING", "RUNNING")
    ]
    return job_rows


def init_table():
    global dataset
    global table
    dataset = client.create_dataset(dataset, exists_ok=True)
    table = client.create_table(table, exists_ok=True)
    until_found = retry.Retry(predicate=retry.if_exception_type(exceptions.NotFound))
    table = client.get_table(table, retry=until_found)


def bq_submit(jobs):
    init_table()
    from pprint import pprint

    pprint(jobs)
    result = client.insert_rows(table, jobs)
    if result:
        pprint(result)
        raise JobInsertionFailed("failed to upload job data to big query")


def get_time_window():
    fmt = r"%Y-%m-%dT%H:%M:%S"
    if not timestamp_file.is_file():
        timestamp_file.touch()
    try:
        start = datetime.strptime(timestamp_file.read_text(), fmt)
    except ValueError:
        start = datetime.fromtimestamp(0)
    # end is now truncated to the last second
    end = datetime.now().replace(microsecond=0)
    return start, end


def write_timestamp(time):
    timestamp_file.write_text(time.isoformat(timespec="seconds"))


def main():
    start, end = get_time_window()
    jobs = load_slurm_jobs(start, end)
    # on failure, an exception will cause the timestamp not to be rewritten. So
    # it will try again next time. If some writes succeed, we don't currently
    # have a way to not submit duplicates next time.
    bq_submit(jobs)
    write_timestamp(end)


parser = argparse.ArgumentParser(description="submit slurm job data to big query")
parser.add_argument(
    "timestamp_file",
    nargs="?",
    action="store",
    type=Path,
    help="specify timestamp file for reading and writing the time window start. Precedence over TIMESTAMP_FILE env var.",
)

if __name__ == "__main__":
    args = parser.parse_args()
    if args.timestamp_file:
        timestamp_file = args.timestamp_file.resolve()
    main()
