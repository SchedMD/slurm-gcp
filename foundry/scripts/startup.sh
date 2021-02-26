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

. /etc/os-release

case "$ID" in
	debian|ubuntu)
		apt-get update
		update="apt-get upgrade -y"
		pacman="apt-get install -y"
		;;
	rhel|centos)
		# reboot on update in case of kernel update
		yum check-updates
		yum install -y epel-release
		update="yum update -y"
		pacman="yum install -y"
		;;
esac

FLAGFILE=/root/os_updated
if [ ! -f $FLAGFILE ]; then
	eval $update

	mkdir -p $(dirname $FLAGFILE)
	touch $FLAGFILE
	reboot
fi

PACKAGES=(
    'wget'
    'python3'
    'python3-pip'
)

PY_PACKAGES=(
    'pyyaml'
    'requests'
    'google-api-python-client'
)

PING_HOST=8.8.8.8
until ( ping -q -w1 -c1 $PING_HOST > /dev/null ) ; do
    echo "Waiting for internet"
    sleep 1
done

echo "$pacman ${PACKAGES[*]}"
until ( $pacman ${PACKAGES[*]} ) ; do
    echo "failed to install packages. Trying again in 5 seconds"
    sleep 5
done

echo   "pip3 install --upgrade ${PY_PACKAGES[*]}"
until ( pip3 install --upgrade ${PY_PACKAGES[*]} ) ; do
    echo "pip3 failed to install python packages. Trying again in 5 seconds"
    sleep 5
done

SETUP_SCRIPT="setup.py"
SETUP_META="setup-script"
DIR="/root/image-scripts"
mkdir -p $DIR
URL="http://metadata.google.internal/computeMetadata/v1/instance/attributes/$SETUP_META"
HEADER="Metadata-Flavor:Google"
echo  "wget -nv --header $HEADER $URL -O $DIR/$SETUP_SCRIPT"
if ! ( wget -nv --header $HEADER $URL -O $DIR/$SETUP_SCRIPT ) ; then
    echo "Failed to fetch $SETUP_META:$SETUP_SCRIPT from metadata"
    exit 1
fi

echo "running python cluster setup script"
chmod +x $DIR/$SETUP_SCRIPT
$DIR/$SETUP_SCRIPT
