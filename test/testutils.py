import logging
import re
import shlex
import subprocess as sp
import time

import psutil
import yaml


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


def backoff(start, cap, mult=1.61, max=None, exc=True):
    val = start
    total = 0
    while True:
        total += val
        if max is not None and total > max:
            if exc:
                raise Exception("Max backoff time reached")
            else:
                break
        yield val
        val = min(cap, val * mult)


def wait_state(get_state, states, max_wait=None):
    wait = backoff(0.5, 10, max=max_wait or 360)

    while True:
        time.sleep(next(wait))
        state = get_state()
        if state in states:
            log.info(f"{state} state found")
            break
    return state


def wait_job_state(cluster, job_id, *states, max_wait=None):
    states = set(states)
    states_str = "{{ {} }}".format(", ".join(states))

    def get_job_state():
        state = cluster.get_job(job_id)["job_state"]
        log.info(f"job {job_id}: {state} waiting for {states_str}")
        return state

    wait_state(get_job_state, states, max_wait)
    return cluster.get_job(job_id)


def wait_node_state(cluster, nodename, *states, max_wait=None):
    states = set(states)
    states_str = "{{ {} }}".format(", ".join(states))

    def get_node_state():
        state = cluster.get_node(nodename)["state"]
        log.info(f"job {nodename}: {state} waiting for {states_str}")
        return state

    wait_state(get_node_state, states, max_wait)
    return cluster.get_node(nodename)


batch_id = re.compile(r"^Submitted batch job (\d+)$")


def sbatch(cluster, cmd):
    out = cluster.login_exec_output(cmd)
    m = batch_id.match(out)
    assert m is not None
    job_id = int(m[1])
    return job_id


def get_zone(instance):
    zone = yaml.safe_load(
        run_out(f"gcloud compute instances describe {instance} --format=yaml(zone)")
    )["zone"]
    return zone


def get_file(cluster, path):
    return cluster.login_exec_output(f"cat {path}")
