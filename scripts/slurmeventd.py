#!/usr/bin/env python3

# Copyright 2021 SchedMD LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


from collections import namedtuple
import logging
import sys
import setup
import util
from pathlib import Path
from google.cloud import pubsub_v1
from util import project, lkp, cfg
from util import config_root_logger, handle_exception, run, publish_message

filename = Path(__file__).name
logfile = (Path(cfg.slurm_log_dir if cfg else '.')/filename).with_suffix('.log')
config_root_logger(filename, level='DEBUG', util_level='DEBUG',
                   logfile=logfile)
log = logging.getLogger(filename)

project_id = project
subscription_id = lkp.hostname

subscriber = pubsub_v1.SubscriberClient()
subscription_path = subscriber.subscription_path(project_id, subscription_id)

SCONTROL = Path(util.cfg.slurm_bin_dir or '')/'scontrol'
StateTuple = namedtuple('StateTuple', 'base,flags')


def natural_keys(text):
    """ String sorting heuristic function for numbers """
    def atoi(text):
        return int(text) if text.isdigit() else text

    return [atoi(c) for c in re.split(r'(\d+)', text)]


def make_tuple(line):
    """ Turn 'part,states' to (part, StateTuple(state)) """
    # Node State: CLOUD, DOWN, DRAIN, FAIL, FAILING, FUTURE, UNKNOWN
    # Partition States: UP, DOWN, DRAIN, INACTIVE
    item, states = line.split(',')
    state = states.split('+')
    state_tuple = StateTuple(state[0], set(state[1:]))
    return (item, state_tuple)


def get_partitions():
    """ Get partitions and their states """
    cmd = (f"{SCONTROL} show partitions | "
           r"grep -oP '^PartitionName=\K(\S+)|State=\K(\S+)' | "
           r"paste -sd',\n'")
    part_lines = run(cmd, shell=True).stdout.rstrip().splitlines()
    slurm_parts = dict(make_tuple(line) for line in part_lines)
    return slurm_parts


def get_nodes():
    """ Get compute nodes, their states and flags """
    cmd = (f"{SCONTROL} show nodes | grep -oP '^NodeName=\K(\S+)|State=\K(\S+)'"
           r" | paste -sd',\n'")
    node_lines = run(cmd, shell=True).stdout.rstrip().splitlines()
    slurm_nodes = {
        part: state for part, state in map(make_tuple, node_lines)
        if 'CLOUD' in state.flags
    }
    return slurm_nodes


def update_partitions(partitions, state):
    log.info(f"Updating partitions states to 'State={state}'.")
    for part, part_state in partitions.items():
        log.debug(f"Current: PartitionName={part} State={part_state}")
        run(f"{SCONTROL} update PartitionName={part} State={state}")


def update_nodes(hostlist, state, reason=None):
    log.debug(f"Updating 'NodeName={hostlist}' to 'State={state}'.")
    cmd = f"{SCONTROL} update NodeName={hostlist} State={state}"
    if reason is not None:
        cmd += f" Reason='{reason}'"
    run(cmd)


def callback(message: pubsub_v1.subscriber.message.Message) -> None:
    from datetime import datetime
    import json

    data = json.loads(message.data.decode('utf-8'))

    def event_reconfig():
        log.debug(f"Handling 'request={data['request']}'.")

        if lkp.instance_role == 'controller':
            # Inactive all partitions to prevent further scheduling
            partitions = get_partitions()
            update_partitions(partitions, 'INACTIVE')

            # Fetch and write new config.yaml
            cfg = util.config_from_metadata(use_cache=False)
            util.save_config(cfg, util.CONFIG_FILE)
            util.cfg = cfg
            util.lkp = util.Lookup(cfg)

            # Regenerate *.conf files
            log.info("Generating new cloud.conf for slurm.conf")
            setup.gen_cloud_conf(util.lkp)
            log.info("Generating new slurm.conf")
            setup.install_slurm_conf(util.lkp)
            log.info("Generating new slurmdbd.conf")
            setup.install_slurmdbd_conf(util.lkp)
            log.info("Generating new gres.conf")
            setup.install_gres_conf(util.lkp)
            log.info("Generating new cgroup.conf")
            setup.install_cgroup_conf()

            # Send restart message to cluster topic
            message_json = json.dumps({
                'request': 'restart',
                'timestamp': datetime.utcnow().isoformat(),
            })
            publish_message(project, util.cfg.pubsub_topic_id, message_json)
        elif lkp.instance_role == 'compute':
            log.info(f"NO-OP for 'Request={data['request']}'.")
        elif lkp.instance_role == 'login':
            log.info(f"NO-OP for 'Request={data['request']}'.")
        else:
            log.error(f"Unknown node role: {lkp.instance_role}")

    def event_restart():
        log.debug(f"Handling 'request={data['request']}'.")

        if lkp.instance_role == 'controller':
            run("systemctl restart slurmctld")
        elif lkp.instance_role == 'compute':
            run("systemctl restart slurmd")
        elif lkp.instance_role == 'login':
            log.info(f"NO-OP for 'Request={data['request']}'.")
        else:
            log.error(f"Unknown node role: {lkp.instance_role}")

    event_handler = dict.get(
        {
            'reconfig': event_reconfig,
            'restart': event_restart,
        },
        data['request'].lower(),
        lambda: log.error(f"Unknown 'Request={data['request']}' received.")
    )
    event_handler()
    message.ack()


def main():
    config_root_logger(filename, level='DEBUG', util_level='DEBUG',
                       logfile=logfile)
    sys.excepthook = handle_exception

    streaming_pull_future = subscriber.subscribe(
        subscription_path, callback=callback)
    log.info(f"Listening for messages on '{subscription_path}'...")

    with subscriber:
        try:
            streaming_pull_future.result()
        except Exception as e:
            log.error(e)
            streaming_pull_future.cancel()
            streaming_pull_future.result()


if __name__ == '__main__':
    main()
