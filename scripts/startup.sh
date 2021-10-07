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
SCRIPTS_DIR=$SLURM_DIR/scripts
mkdir -p $SCRIPTS_DIR

FLAGFILE=$SLURM_DIR/slurm_configured_do_not_remove
if [ -f $FLAGFILE ]; then
	echo "Slurm was previously configured, quitting"
	exit 0
fi
touch $FLAGFILE

PING_HOST=8.8.8.8
if ( ! ping -q -w1 -c1 $PING_HOST > /dev/null ) ; then
	echo No internet access detected
fi


function fetch_scripts {
	# fetch project metadata
	URL="http://metadata.google.internal/computeMetadata/v1"
	HEADER="Metadata-Flavor:Google"
	CURL="curl --fail --header $HEADER"
	if ! CLUSTER=$($CURL $URL/instance/attributes/cluster_name); then
		echo cluster name not found in instance metadata, quitting
		return 1
	fi
	if ! METADATA=$($CURL $URL/project/attributes/$CLUSTER-slurm-metadata); then
		echo cluster data not found in project metadata, quitting
		return 1
	fi
	if SETUP_SCRIPT=$(jq -re '."setup-script"' <<< $METADATA); then
		echo updating setup.py from project metadata
		printf '%s' "$SETUP_SCRIPT" > $SETUP_SCRIPT_FILE
	else
		echo setup-script not found in project metadata, skipping update
	fi
	if UTIL_SCRIPT=$(jq -re '."util-script"' <<< $METADATA); then
		echo updating util.py from project metadata
		printf '%s' "$UTIL_SCRIPT" > $UTIL_SCRIPT_FILE
	else
		echo util-script not found in project metadata, skipping update
	fi
}

SETUP_SCRIPT_FILE=$SCRIPTS_DIR/setup.py
UTIL_SCRIPT_FILE=$SCRIPTS_DIR/util.py
fetch_scripts

echo "running python cluster setup script"
chmod +x $SETUP_SCRIPT
exec $SETUP_SCRIPT
