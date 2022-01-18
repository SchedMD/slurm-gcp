#!/usr/bin/env python

import argparse
import os
import sys
import json
from datetime import datetime, timedelta
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

# still left out
# AveCPU
# SystemCPU
# CPUTime

job_schema = (
    SchemaField(
        "job_id", "INT64", mode="REQUIRED", description="job id from slurm accounting"
    ),
    SchemaField("state", "STRING", mode="REQUIRED", description="Final job state"),
    SchemaField("job_name", "STRING", mode="NULLABLE", description="Job name"),
    SchemaField("partition", "STRING", mode="NULLABLE", description="job partition"),
    SchemaField(
        "submit_time", "DATETIME", mode="NULLABLE", description="job submit time"
    ),
    SchemaField(
        "start_time", "DATETIME", mode="NULLABLE", description="job start time"
    ),
    SchemaField("end_time", "DATETIME", mode="NULLABLE", description="job end time"),
    SchemaField("elapsed_time", "TIME", mode="NULLABLE", description="job submit time"),
    SchemaField("timelimit", "TIME", mode="NULLABLE", description="job time limit"),
    SchemaField(
        "num_nodes", "INT64", mode="NULLABLE", description="Number of nodes in job"
    ),
    SchemaField(
        "num_tasks", "INT64", mode="NULLABLE", description="Number of tasks in job"
    ),
    SchemaField(
        "nodelist", "STRING", mode="NULLABLE", description="nodes allocated in job"
    ),
    SchemaField(
        "cpus", "INT64", mode="NULLABLE", description="total cpus allocated to job"
    ),
    SchemaField(
        "user", "STRING", mode="NULLABLE", description="user responsible for the job"
    ),
    SchemaField(
        "group",
        "STRING",
        mode="NULLABLE",
        description="user group responsible for the job",
    ),
    SchemaField("wckey", "STRING", mode="NULLABLE", description="job wckey"),
    SchemaField(
        "assoc_user",
        "STRING",
        mode="NULLABLE",
        description="slurm association user for job",
    ),
    SchemaField(
        "account", "STRING", mode="NULLABLE", description="parent account for job"
    ),
    SchemaField("qos", "STRING", mode="NULLABLE", description="job qos"),
    SchemaField("comment", "STRING", mode="NULLABLE", description="Job comment"),
    SchemaField("exit_code", "INT64", mode="NULLABLE", description="job exit code"),
    SchemaField(
        "tres_usage_tot",
        "STRING",
        mode="NULLABLE",
        description="Tres total usage by all tasks",
    ),
)

client = bq.Client(project=cfg.project, credentials=def_creds)
dataset_id = f"{cfg.cluster_name}_job_data"
dataset = bq.DatasetReference(project=cfg.project, dataset_id=dataset_id)
table = bq.Table(bq.TableReference(dataset, f"{cfg.cluster_name}_jobs"), job_schema)


class JobInsertionFailed(Exception):
    pass


def make_job_row(job):
    def make_datetime(timestamp):
        return datetime.fromtimestamp(timestamp).isoformat(timespec="seconds")

    job_row = {
        "job_id": job["job_id"],
        "state": job["state"]["current"],
        "job_name": job["name"],
        "partition": job["partition"],
        "submit_time": make_datetime(job["time"]["submission"]),
        "start_time": make_datetime(job["time"]["start"]),
        "end_time": make_datetime(job["time"]["end"]),
        "elapsed_time": job["time"]["elapsed"],
        "timelimit": job["time"]["limit"],
        "num_nodes": job["allocation_nodes"],
        "num_tasks": None,
        "nodelist": job["nodes"] if job["nodes"] != "None assigned" else None,
        "cpus": job["required"]["CPUs"],
        "user": job["association"]["user"],
        "group": job["group"],
        "wckey": job["wckey"]["wckey"],
        "assoc_user": job["association"]["user"],
        "account": job["association"]["account"],
        "qos": job["qos"],
        "comment": job["comment"]["job"],
        "exit_code": job["exit_code"]["return_code"],
        "tres_usage_tot": None,
        "alloc_cpus": job["tres"]["allocated"][0]["count"],
        "alloc_nodes": job["tres"]["allocated"][2]["count"],
    }
    return job_row


def load_slurm_jobs(start, end):
    start_iso = start.isoformat(timespec="seconds")
    end_iso = end.isoformat(timespec="seconds")
    cmd = f"{SACCT} --start {start_iso} --end {end_iso} -X -D --json"
    text = run(cmd).stdout
    accounting = json.loads(text)
    job_rows = [
        make_job_row(job)
        for job in accounting["jobs"]
        if job["statel"]["current"] not in ("PENDING", "RUNNING")
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
