#!/bin/bash
# Copyright 2019 SchedMD LLC.
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

set -e

SLURM_DIR=/slurm
FLAGFILE=$SLURM_DIR/slurm_configured_do_not_remove
SCRIPTS_DIR=$SLURM_DIR/scripts

function show_help {
cat << EOF
usage:  ${0##*/} -f
Check project metadata for startup-script, setup-script, and util-script.
Download and copy to $SCRIPTS_DIR.
	-f	Force run setup.py. Otherwise, $FLAGFILE will signal not to run
		setup.py
EOF
}

function fetch_scripts {
	# fetch project metadata
	URL="http://metadata.google.internal/computeMetadata/v1"
	HEADER="Metadata-Flavor:Google"
	CURL="curl -sS --fail --header $HEADER"
	if ! CLUSTER=$($CURL $URL/instance/attributes/slurm_cluster_name); then
		echo cluster name not found in instance metadata, quitting
		return 1
	fi
	if ! META_DEVEL=$($CURL $URL/project/attributes/$CLUSTER-slurm-devel); then
		return
	fi
	echo devel data found in project metadata, looking to update scripts
	if STARTUP_SCRIPT=$(jq -re '."startup-script"' <<< "$META_DEVEL"); then
		echo updating startup.sh from project metadata
		printf '%s' "$STARTUP_SCRIPT" > $STARTUP_SCRIPT_FILE
	else
		echo startup-script not found in project metadata, skipping update
	fi
	if SETUP_SCRIPT=$(jq -re '."setup-script"' <<< "$META_DEVEL"); then
		echo updating setup.py from project metadata
		printf '%s' "$SETUP_SCRIPT" > $SETUP_SCRIPT_FILE
	else
		echo setup-script not found in project metadata, skipping update
	fi
	if UTIL_SCRIPT=$(jq -re '."util-script"' <<< "$META_DEVEL"); then
		echo updating util.py from project metadata
		printf '%s' "$UTIL_SCRIPT" > $UTIL_SCRIPT_FILE
	else
		echo util-script not found in project metadata, skipping update
	fi
	if RESUME_SCRIPT=$(jq -re '."slurm-resume"' <<< "$META_DEVEL"); then
		echo updating resume.py from project metadata
		printf '%s' "$RESUME_SCRIPT" > $RESUME_SCRIPT_FILE
	else
		echo slurm-resume not found in project metadata, skipping update
	fi
	if SUSPEND_SCRIPT=$(jq -re '."slurm-suspend"' <<< "$META_DEVEL"); then
		echo updating suspend.py from project metadata
		printf '%s' "$SUSPEND_SCRIPT" > $SUSPEND_SCRIPT_FILE
	else
		echo slurm-suspend not found in project metadata, skipping update
	fi
	if SLURMSYNC_SCRIPT=$(jq -re '."slurmsync"' <<< "$META_DEVEL"); then
		echo updating slurmsync.py from project metadata
		printf '%s' "$SLURMSYNC_SCRIPT" > $SLURMSYNC_SCRIPT_FILE
	else
		echo slurmsync not found in project metadata, skipping update
	fi
	if SLURMEVENTD_SCRIPT=$(jq -re '."slurmeventd"' <<< "$META_DEVEL"); then
		echo "updating slurmeventd.py from project metadata"
		printf '%s' "$SLURMEVENTD_SCRIPT" > $SLURMEVENTD_SCRIPT_FILE
	else
		echo "slurmeventd not found in project metadata, skipping update"
	fi
}

OPTIND=1
force=false
while getopts hf opt; do
	case $opt in
		f)	force=true
			echo force run setup.py enabled
		;;
		h)	show_help >&2
			exit 0
		;;
		*)	show_help >&2
			exit 1
		;;
	esac
done

PING_HOST=8.8.8.8
if ( ! ping -q -w1 -c1 $PING_HOST > /dev/null ) ; then
	echo No internet access detected
fi

mkdir -p $SCRIPTS_DIR

STARTUP_SCRIPT_FILE=$SCRIPTS_DIR/startup.sh
SETUP_SCRIPT_FILE=$SCRIPTS_DIR/setup.py
UTIL_SCRIPT_FILE=$SCRIPTS_DIR/util.py
RESUME_SCRIPT_FILE=$SCRIPTS_DIR/resume.py
SUSPEND_SCRIPT_FILE=$SCRIPTS_DIR/suspend.py
SLURMSYNC_SCRIPT_FILE=$SCRIPTS_DIR/slurmsync.py
SLURMEVENTD_SCRIPT_FILE=$SCRIPTS_DIR/slurmeventd.py
fetch_scripts

if ! "$force" && [ -f $FLAGFILE ]; then
	echo "Slurm was previously configured, quitting"
	exit 0
fi
touch $FLAGFILE

echo "running python cluster setup script"
chmod +x $SETUP_SCRIPT_FILE
python3 $SCRIPTS_DIR/util.py
exec $SETUP_SCRIPT_FILE
