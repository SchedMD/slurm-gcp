#!/bin/bash
# Copyright (C) SchedMD LLC.
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
if [[ -z "$HOME" ]]; then
	# google-startup-scripts.service lacks environment variables
	HOME="$(getent passwd "$(whoami)" | cut -d: -f6)"
fi

METADATA_SERVER="metadata.google.internal"
URL="http://$METADATA_SERVER/computeMetadata/v1"
HEADER="Metadata-Flavor:Google"
CURL="curl -sS --fail --header $HEADER"

function devel::zip() {
	local BUCKET="$($CURL $URL/instance/attributes/slurm_bucket_path)"
	if [[ -z $BUCKET ]]; then
		echo "ERROR: No bucket path detected."
		return 1
	fi

	local SLURM_ZIP_URL="$BUCKET/slurm-gcp-devel.zip"
	local SLURM_ZIP_FILE="$HOME/slurm-gcp-devel.zip"
	local SLURM_ZIP_DIR="$HOME/slurm-gcp-devel"
	eval $(gsutil cp "$SLURM_ZIP_URL" "$SLURM_ZIP_FILE")
	if ! [[ -f "$SLURM_ZIP_FILE" ]]; then
		echo "INFO: No development files downloaded. Skipping."
		return 0
	fi
	unzip -o "$SLURM_ZIP_FILE" -d "$SCRIPTS_DIR"
	rm -rf "$SLURM_ZIP_FILE" "$SLURM_ZIP_DIR" # Clean up
	echo "INFO: Finished inflating '$SLURM_ZIP_FILE'."

	chown slurm:slurm -R "$SCRIPTS_DIR"
	chmod 700 -R "$SCRIPTS_DIR"
	echo "INFO: Updated permissions of files in '$SCRIPTS_DIR'."
}

PING_METADATA="ping -q -w1 -c1 $METADATA_SERVER"
echo "INFO: $PING_METADATA"
for i in $(seq 10); do
    [ $i -gt 1 ] && sleep 5;
    $PING_METADATA > /dev/null && s=0 && break || s=$?;
    echo "ERROR: Failed to contact metadata server, will retry"
done
if [ $s -ne 0 ]; then
    echo "ERROR: Unable to contact metadata server, aborting"
    wall -n '*** Slurm setup failed in the startup script! see `journalctl -u google-startup-scripts` ***'
    exit 1
else
    echo "INFO: Successfully contacted metadata server"
fi

GOOGLE_DNS=8.8.8.8
PING_GOOGLE="ping -q -w1 -c1 $GOOGLE_DNS"
echo "INFO: $PING_GOOGLE"
for i in $(seq 5); do
    [ $i -gt 1 ] && sleep 2;
    $PING_GOOGLE > /dev/null && s=0 && break || s=$?;
	echo "failed to ping Google DNS, will retry"
done
if [ $s -ne 0 ]; then
    echo "WARNING: No internet access detected"
else
    echo "INFO: Internet access detected"
fi

mkdir -p $SCRIPTS_DIR

SETUP_SCRIPT_FILE=$SCRIPTS_DIR/setup.py
UTIL_SCRIPT_FILE=$SCRIPTS_DIR/util.py

devel::zip

if [ -f $FLAGFILE ]; then
	echo "WARNING: Slurm was previously configured, quitting"
	exit 0
fi
touch $FLAGFILE

function fetch_feature {
	if slurmd_feature="$($CURL $URL/instance/attributes/slurmd_feature)"; then
		echo "$slurmd_feature"
	else
		echo ""
	fi
}
SLURMD_FEATURE="$(fetch_feature)"

echo "INFO: Running python cluster setup script"
chmod +x $SETUP_SCRIPT_FILE
python3 $SCRIPTS_DIR/util.py
if [[ -n "$SLURMD_FEATURE" ]]; then
	echo "INFO: Running dynamic node setup."
	exec $SETUP_SCRIPT_FILE --slurmd-feature="$SLURMD_FEATURE"
else
	exec $SETUP_SCRIPT_FILE
fi
