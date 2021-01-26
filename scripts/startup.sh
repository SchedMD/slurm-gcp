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

#set -e

FLAGFILE=/slurm/slurm_configured_do_not_remove
if [ -f $FLAGFILE ]; then
	echo "Slurm was previously configured, quitting"
	exit 0
fi
mkdir -p $(dirname $FLAGFILE)
touch $FLAGFILE

PING_HOST=8.8.8.8
if ( ! ping -q -w1 -c1 $PING_HOST > /dev/null ) ; then
	echo No internet access detected
fi

URL="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
HEADER="Metadata-Flavor:Google"

SETUP_MOUNT="/slurm/scripts"
SETUP_SCRIPT="setup.py"
if MOUNT=$(curl -f -s -H $HEADER $URL/external-setup-mount); then
	# repeat apt-get update to avoid lock
	until apt-get update; do sleep 5; done
	until apt-get install -y nfs-common jq; do sleep 5; done
	REMOTE=$(jq -r .remote <<< "$MOUNT")
	TYPE=$(jq -r .type <<< "$MOUNT")
	OPTIONS=$(jq -r .options <<< "$MOUNT")
	if [ ! -z "$OPTIONS" ]; then
		OPTIONS="-o $OPTIONS"
	fi

	cmd="mount -t $TYPE $REMOTE $SETUP_MOUNT $OPTIONS"
	echo found metadata for external setup script location, mounting
	echo $cmd
	mkdir -p $SETUP_MOUNT
	$cmd
	cd $SETUP_MOUNT
	./$SETUP_SCRIPT
	exit
fi

DIR="/tmp"
SETUP_SCRIPT="setup.py"
SETUP_META="setup-script"
cmd="wget -nv --header $HEADER $URL/setup-script -O $DIR/$SETUP_SCRIPT"
echo $cmd
if ! ( $cmd ) ; then
    echo "Failed to fetch $SETUP_META:$SETUP_SCRIPT from metadata"
    exit 1
fi

echo "running python cluster setup script"
chmod +x $DIR/$SETUP_SCRIPT
$DIR/$SETUP_SCRIPT
