import json
import logging
import os
import pty
import re
import select
import socket
import subprocess
import sys
import time
from collections import defaultdict
from contextlib import closing
from dataclasses import dataclass, field
from pathlib import Path
from string import Template

import paramiko
from tftest import TerraformTest
from testutils import backoff, spawn, run_out, term_proc


log = logging.getLogger()
log.setLevel("INFO")
handler = logging.StreamHandler(sys.stdout)
handler.setLevel("INFO")
# formatter = logging.Formatter()
log.addHandler(handler)


def get_gcloud_user():
    auth = json.loads(run_out("gcloud auth list --format=json"))
    try:
        user = next(d["account"] for d in auth if d["status"] == "ACTIVE")
    except StopIteration:
        raise Exception("No gcloud user found")
    return re.sub(r"\W", "_", user)


def trim_self_link(link: str):
    """get resource name from self link url, eg.
    https://.../v1/projects/<project>/regions/<region>
    -> <region>
    """
    try:
        return link[link.rindex("/") + 1 :]
    except ValueError:
        raise Exception(f"'/' not found, not a self link: '{link}' ")


class NoPortFoundError(Exception):
    pass


def find_open_port():
    while True:
        with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as s:
            s.bind(("localhost", 0))
            s.listen(1)
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            port = s.getsockname()[1]
        yield port


def start_service(service):
    for port in find_open_port():
        try:
            s = service(port)
        except Exception:
            continue
        if s is not None:
            return port, s
    else:
        raise NoPortFoundError("No available port found")
    return -1


class DefaultKeyDict(defaultdict):
    def __missing__(self, key):
        if self.default_factory:
            dict.__setitem__(self, key, self.default_factory(key))
            return self[key]
        else:
            defaultdict.__missing__(self, key)

    def __repr__(self):
        return "{}({})".format(
            type(self).__name__, ", ".join(f"{k}:{v}" for k, v in self.items())
        )


@dataclass
class Configuration:
    cluster_name: str
    project_id: str
    moduledir: Path
    tfvars_file: Path
    tfvars: dict
    tf: TerraformTest = field(init=False)
    image_project: str
    image: str = None
    image_family: str = None

    def __post_init__(self):
        self.tfvars.update(
            {
                "project_id": self.project_id,
                "slurm_cluster_name": self.cluster_name,
            }
        )
        self.tf = TerraformTest(self.moduledir)
        tmp = self._template_tfvars = self.tfvars_file
        self.tfvars_file = self._template_tfvars.with_name(
            f"{self.cluster_name}-{tmp.stem}{''.join(tmp.suffixes[:-1])}"
        )
        self.tfvars_file.write_text(
            Template(tmp.read_text()).substitute(
                {
                    k: f'"{str(v)}"' if v is not None else "null"
                    for k, v in self.__dict__.items()
                }
            )
        )


class Tunnel:
    def __init__(self, host, target_port=22):
        self.host = host
        self.target_port = target_port
        self.port, self.proc = self._start_tunnel(host, target_port)
        self.closed = False

    def __del__(self):
        self.close()

    def __repr__(self):
        return f"Tunnel({self.port}:{self.host}:{self.target_port}<{self.proc.pid}>)"

    def close(self):
        term_proc(self.proc)

    def _start_tunnel(self, instance, target_port):
        listen = re.compile(r"^Listening on port \[\d+\].\n$")
        log.info(f"start tunnel {instance}:{target_port}")

        def tunnel(port):
            """Attempt to create an iap tunnel on the local port"""
            # the pty makes gcloud output a message on success, allowing us to
            # proceed faster
            stdoutfd, peer = pty.openpty()
            stdout = os.fdopen(stdoutfd)
            proc = spawn(
                f"gcloud compute start-iap-tunnel {instance} {target_port} --local-host-port=localhost:{port}",
                stderr=subprocess.PIPE,
                stdout=peer,
                stdin=subprocess.DEVNULL,
            )
            stdout_sel = select.poll()
            stdout_sel.register(stdout, select.POLLIN)
            for w in backoff(0.5, 1, mult=1.1, max=20, exc=False):
                time.sleep(w)
                if proc.poll() is None:
                    if stdout_sel.poll(1):
                        out = stdout.readline()
                        log.debug(f"gcloud iap-tunnel: {out}")
                        if listen.match(out):
                            log.debug(f"gcloud iap-tunnel created on port {port}")
                            return proc
                else:
                    stderr = proc.stderr.read()
                    log.debug(
                        f"gcloud iap-tunnel failed on port {port}, rc: {proc.returncode}, stderr: {stderr}"
                    )
                    return None
            log.error(f"gcloud iap-tunnel timed out on port {port}")
            proc.kill()
            return None

        return start_service(tunnel)


class Cluster:
    def __init__(self, tf, user=None):
        self.user = user or get_gcloud_user()

        self.tf = tf

        self.tunnels = DefaultKeyDict(lambda host: Tunnel(host))  # type: ignore
        self.ssh_conns = {}

        self.connected = False
        self.active = False

        self.keyfile = Path("gcp_login_id")
        self.keyfile.write_text(os.environ["GCP_LOGIN_ID"])
        self.keyfile.chmod(0o600)

    def activate(self):
        if not self.active:
            self.wait_on_active()

    def wait_on_active(self):
        node_state = re.compile(r"State=(\S+)\s")
        MAX_WAIT = 120
        total = 0
        wait_time = backoff(2, 20)
        while total < MAX_WAIT:
            wait = next(wait_time)
            total += wait
            time.sleep(wait)
            result = self.controller_exec("scontrol show -o nodes")
            if result["exit_status"] == 0 and all(
                s[1].startswith("IDLE")
                for s in node_state.finditer(result["stdout"])
                if s[1]
            ):
                break
        else:
            raise Exception("Cluster never came up")
        self.active = True

    def power_down(self):
        all_nodes = ",".join(
            p.nodes for p in self.api.slurmctld_get_partitions().partitions
        )
        self.login_exec(
            f"sudo $(which scontrol) update nodename={all_nodes} state=power_down"
        )

    def ssh(self, instance):
        if instance in self.ssh_conns:
            return self.ssh_conns[instance]
        log.info(f"start ssh connection to {trim_self_link(instance)}")

        ssh = paramiko.SSHClient()
        key = paramiko.RSAKey.from_private_key_file(self.keyfile)
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        tries = 12
        wait = backoff(1, 20)
        while tries > 0:
            tun = self.tunnels[instance]
            try:
                ssh.connect("127.0.0.1", username=self.user, pkey=key, port=tun.port)
                break
            except paramiko.ssh_exception.NoValidConnectionsError:
                log.error("ssh connection failed")
                tries -= 1
                time.sleep(next(wait))
                tun = self.tunnels.pop(instance)
                tun.close()
                continue
        else:
            log.error(f"Cannot connect through tunnel: {instance}")
            raise Exception(f"Cannot connect through tunnel: {instance}")
        self.ssh_conns[instance] = ssh
        self.connected = True
        return ssh

    def _close_ssh(self, instance):
        ssh = self.ssh_conns.pop(instance, None)
        if ssh:
            ssh.close()
        tun = self.tunnels.pop(instance, None)
        if tun:
            tun.close()

    def disconnect(self):
        for instance in list(self.ssh_conns):
            self._close_ssh(instance)
        self.keyfile.unlink()

    @property
    def controller_ssh(self):
        return self.ssh(self.controller_link)

    @property
    def login_ssh(self):
        return self.ssh(self.login_link)

    def exec_cmd(self, ssh, cmd, input="", prefix="", timeout=60, quiet=False):
        if not quiet:
            log.info(f"{prefix}: {cmd}")
        start = time.time()

        stdin, stdout, stderr = ssh.exec_command(cmd, timeout)
        if input:
            stdin.write(input)
            stdin.flush()
            stdin.channel.shutdown_write()
        status = stdout.channel.recv_exit_status()
        stdout = stdout.read().decode()
        stderr = stderr.read().decode()
        if status:
            raise Exception(f"Error running command '{cmd}' stderr:{stderr}")

        duration = round(time.time() - start, 3)
        start = round(start, 3)

        if not quiet:
            log.debug(f"{stdout}")
            if status:
                log.debug(f"{stderr}")

        result = {
            "command": cmd,
            "start_time": start,
            "duration": duration,
            "exit_status": status,
            "stdout": stdout,
            "stderr": stderr,
        }
        return result

    def login_exec_output(self, *args, **kwargs):
        r = self.login_exec(*args, **kwargs)
        return r["stdout"] or r["stderr"]

    def controller_exec_output(self, *args, **kwargs):
        r = self.controller_exec(*args, **kwargs)
        return r["stdout"] or r["stderr"]

    def login_exec(self, *args, **kwargs):
        return self.exec_cmd(self.login_ssh, *args, prefix=self.login_name, **kwargs)

    def controller_exec(self, *args, **kwargs):
        return self.exec_cmd(
            self.controller_ssh, *args, prefix=self.controller_name, **kwargs
        )

    def partitions(self):
        return self.tf.output()["slurm_partitions"]

    @property
    def controller_link(self):
        return self.tf.output()["slurm_controller_instance_self_links"][0]

    @property
    def controller_name(self):
        return trim_self_link(self.controller_link)

    @property
    def login_link(self):
        return self.tf.output()["slurm_login_instance_self_links"][0]

    @property
    def login_name(self):
        return trim_self_link(self.login_link)

    def get_jobs(self):
        return json.loads(self.login_exec("squeue --json")["stdout"])["jobs"]

    def get_job(self, job_id):
        return next((j for j in self.get_jobs() if j["job_id"] == job_id), None)

    def get_nodes(self):
        return json.loads(self.login_exec("sinfo --json")["stdout"])["nodes"]

    def get_node(self, nodename):
        return next((n for n in self.get_nodes() if n["name"] == nodename), None)
