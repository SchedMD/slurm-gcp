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


import logging
import sys
from pathlib import Path
from concurrent.futures import TimeoutError
from google.cloud import pubsub_v1
from util import project, cfg, lkp, dirs
from util import config_root_logger, handle_exception, run

filename = Path(__file__).name
logfile = (Path(dirs.log)/filename).with_suffix('.log')
config_root_logger(filename, level='DEBUG', util_level='DEBUG',
                        logfile=logfile)
log = logging.getLogger(filename)

project_id = project
subscription_id = cfg.hostname

subscriber = pubsub_v1.SubscriberClient()
subscription_path = subscriber.subscription_path(project_id, subscription_id)


def callback(message: pubsub_v1.subscriber.message.Message) -> None:
    import json

    data = json.loads(message.data.decode('utf-8'))

    def event_restart():
        log.debug(f"Handling request={data['request']}.")

        if lkp.instance_role == 'controller':
            run("systemctl restart slurmctld")
        elif lkp.instance_role == 'compute':
            run("systemctl restart slurmd")
        elif lkp.instance_role == 'login':
            log.info(f"NO OP for Request={data['request']}.")
        else:
            log.error(f"Unknown node role: {lkp.instance_role}")

    event_handler = dict.get(
        {
            'RESTART': event_restart,
        },
        data['request'],
        lambda: log.error(f"Unknown Request={data['request']} received.")
    )
    event_handler()
    message.ack()


def main():
    config_root_logger(filename, level='DEBUG', util_level='DEBUG',
                            logfile=logfile)
    sys.excepthook = handle_exception

    streaming_pull_future = subscriber.subscribe(subscription_path, callback=callback)
    print(f"Listening for messages on '{subscription_path}'...\n")

    with subscriber:
        try:
            res = streaming_pull_future.result()
            print(res.get('data').decode('utf-8'))
        except TimeoutError:
            streaming_pull_future.cancel()
            streaming_pull_future.result()


if __name__ == '__main__':
    main()
