import logging
import re
import shlex
import subprocess as sp
import sys
import time

import psutil
import yaml

scripts = "../scripts"
if scripts not in sys.path:
    sys.path.append(scripts)
import util  # noqa: F401 E402
from util import backoff_delay, NSDict  # noqa: F401 E402


log = logging.getLogger()
log.setLevel(logging.INFO)


def term_proc(proc):
    try:
        psproc = psutil.Process(proc.pid)
    except psutil.NoSuchProcess:
        log.debug(f"process with pid {proc.pid} doesn't exist")
        return
    for child in psproc.children(recursive=True):
        child.terminate()
        try:
            child.wait(timeout=1)
        except psutil.TimeoutExpired:
            log.error(f"killing {child.pid}")
            child.kill()
    proc.terminate()
    try:
        proc.wait(timeout=1)
    except sp.TimeoutExpired:
        log.error(f"killing {proc.pid}")
        proc.kill()


def run(
    cmd,
    wait=0,
    quiet=False,
    get_stdout=False,
    shell=False,
    universal_newlines=True,
    **kwargs,
):
    """run in subprocess. Optional wait after return."""
    if not quiet:
        log.debug(f"run: {cmd}")
    if get_stdout:
        kwargs["stdout"] = sp.PIPE

    args = cmd if shell else shlex.split(cmd)
    ret = sp.run(args, shell=shell, universal_newlines=universal_newlines, **kwargs)
    if wait:
        time.sleep(wait)
    return ret


def run_out(cmd, **kwargs):
    kwargs["get_stdout"] = True
    kwargs["universal_newlines"] = True
    return run(cmd, **kwargs).stdout


def spawn(cmd, quiet=False, shell=False, **kwargs):
    """nonblocking spawn of subprocess"""
    if not quiet:
        log.debug(f"spawn: {cmd}")
    kwargs["universal_newlines"] = True
    args = cmd if shell else shlex.split(cmd)
    return sp.Popen(args, shell=shell, **kwargs)


def wait_until(check, *args, max_wait=None):
    if max_wait is None:
        max_wait = 360
    for wait in backoff_delay(1, count=20, timeout=max_wait):
        if check(*args):
            return True
        time.sleep(wait)
    return False


def wait_job_state(cluster, job_id, *states, max_wait=None):
    states = set(states)
    states_str = "{{ {} }}".format(", ".join(states))

    def is_job_state():
        state = cluster.get_job(job_id)["job_state"]
        log.info(f"job {job_id}: {state} waiting for {states_str}")
        return state in states

    if not wait_until(is_job_state, max_wait=max_wait):
        raise Exception(f"job {job_id} did not reach expected state")
    return cluster.get_job(job_id)


def wait_node_state(cluster, nodename, *states, max_wait=None):
    states = set(states)
    states_str = "{{ {} }}".format(", ".join(states))

    def is_node_state():
        state = cluster.get_node(nodename)["state"]
        log.info(f"node {nodename}: {state} waiting for {states_str}")
        return state in states

    wait_until(is_node_state, max_wait=max_wait)
    return cluster.get_node(nodename)


# https://stackoverflow.com/questions/3844801/check-if-all-elements-in-a-list-are-identical
def all_equal(coll):
    """Return true if coll is empty or all elements are equal"""
    it = iter(coll)
    try:
        first = next(it)
    except StopIteration:
        return True
    return all(first == x for x in it)


batch_id = re.compile(r"^Submitted batch job (\d+)$")


def sbatch(cluster, cmd):
    submit = cluster.login_exec(cmd)
    m = batch_id.match(submit.stdout)
    if submit.exit_status or m is None:
        raise Exception(f"job submit failed: {yaml.safe_dump(submit.to_dict())}")
    assert m is not None
    job_id = int(m[1])
    return job_id


def get_zone(instance):
    zone = yaml.safe_load(
        run_out(f"gcloud compute instances describe {instance} --format=yaml(zone)")
    )["zone"]
    return zone
