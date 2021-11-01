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
import os
import subprocess
from pathlib import Path

import setup
import util


filename = Path(__file__).name
logfile = (Path(util.dirs.log/filename)).with_suffix('.log')
util.config_root_logger(filename, level='DEBUG', util_level='DEBUG',
                        logfile=logfile)
log = logging.getLogger(filename)
setup.log.disabled=False


def event_member_join():
    """ Handles 'member-join' type events """
    pass


def event_member_leave():
    """ Handles 'member-leave' type events """
    pass


def event_member_failed():
    """ Handles 'member-failed' type events """
    pass


def event_member_update():
    """ Handles 'member-update' type events """
    pass


def event_member_reap():
    """ Handles 'member-reap' type events """
    pass


def event_user():
    """ Handles 'user' type events """
    SERF_USER_EVENT = os.getenv('SERF_USER_EVENT')
    SERF_USER_LTIME = os.getenv('SERF_USER_LTIME')
    log.debug(
        f"SERF_USER_EVENT={SERF_USER_EVENT} SERF_USER_LTIME={SERF_USER_LTIME}")


    def restart_slurmd():
        """ Handles 'user:restart' event """
        if util.lkp.instance_role == 'compute':
            log.info("Restarting slurm daemon: slurmd")
            util.run("systemctl restart slurmd")
        else:
            log.info(f"SERF_USER_EVENT={SERF_USER_EVENT} : No Operation")


    def update_scripts():
        """" Handles 'user:update-scripts' event """
        setup.fetch_devel_scripts()


    serf_event_user_handler = dict.get(
        {
            'restart-slurmd': restart_slurmd,
            'update-scripts': update_scripts,
        },
        SERF_USER_EVENT,
        lambda: log.error(
            f"Unknown SERF_USER_EVENT={SERF_USER_EVENT} received.")
    )
    serf_event_user_handler()


def event_query():
    """ Handles 'query' type events """
    SERF_QUERY_NAME = os.getenv('SERF_QUERY_NAME')
    SERF_QUERY_LTIME = os.getenv('SERF_QUERY_LTIME')
    log.debug(
        f"SERF_QUERY_NAME={SERF_QUERY_NAME} SERF_QUERY_LTIME={SERF_QUERY_LTIME}")

    serf_event_query_handler = dict.get(
        {},
        SERF_QUERY_NAME,
        lambda: log.error(
            f"Unknown SERF_QUERY_NAME={SERF_QUERY_NAME} received.")
    )
    serf_event_query_handler()


def main():
    log.debug(f"SERF_EVENT={SERF_EVENT}")
    serf_event_handler = dict.get(
        {
            'member-join': event_member_join,
            'member-leave': event_member_leave,
            'member-failed': event_member_failed,
            'member-update': event_member_update,
            'member-reap': event_member_reap,
            'user': event_user,
            'query': event_query,
        },
        SERF_EVENT,
        lambda: log.error(f"Unknown SERF_EVENT={SERF_EVENT} received.")
    )
    serf_event_handler()


SERF_EVENT = os.getenv('SERF_EVENT')
SERF_SELF_NAME = os.getenv('SERF_SELF_NAME')
SERF_SELF_ROLE = os.getenv('SERF_SELF_ROLE')


if __name__ == '__main__':
    try:
        main()
    except subprocess.TimeoutExpired as e:
        log.error(f"""TimeoutExpired:
        command={e.cmd}
        timeout={e.timeout}
        stdout:
    {e.stdout.strip()}
        stderr:
    {e.stderr.strip()}
    """)
    except subprocess.CalledProcessError as e:
        log.error(f"""CalledProcessError:
    command={e.cmd}
    returncode={e.returncode}
    stdout:
{e.stdout.strip()}
    stderr:
{e.stderr.strip()}
""")
    except Exception as e:
        log.exception(e)
