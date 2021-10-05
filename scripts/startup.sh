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

# setup script in metadata takes precedence
SETUP_META="setup-script"
URL="http://metadata.google.internal/computeMetadata/v1/instance/attributes/$SETUP_META"
HEADER="Metadata-Flavor:Google"
SETUP_SCRIPT="$SCRIPTS_DIR/setup.py"
get_metadata="wget -nv --header $HEADER $URL -O $SETUP_SCRIPT"
echo $get_metadata
if ! ( $get_metadata ) ; then
    echo "setup script $SETUP_META not found in metadata"
fi

echo "running python cluster setup script"
chmod +x $SETUP_SCRIPT
exec $SETUP_SCRIPT
