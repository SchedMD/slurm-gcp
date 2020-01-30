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

PACKAGES=(
        'bind-utils'
        'environment-modules'
        'epel-release'
        'gcc'
        'git'
        'hwloc'
        'hwloc-devel'
        'libibmad'
        'libibumad'
        'lua'
        'lua-devel'
        'man2html'
        'mariadb'
        'mariadb-devel'
        'mariadb-server'
        'munge'
        'munge-devel'
        'munge-libs'
        'ncurses-devel'
        'nfs-utils'
        'numactl'
        'numactl-devel'
        'openssl-devel'
        'pam-devel'
        'perl-ExtUtils-MakeMaker'
        'python3'
        'python3-pip'
        'readline-devel'
        'rpm-build'
        'rrdtool-devel'
        'vim'
        'wget'
        'tmux'
        'pdsh'
        'openmpi'
        'yum-utils'
    )

PY_PACKAGES=(
        'pyyaml'
        'requests'
        'google-api-python-client'
    )

PING_HOST=8.8.8.8
until ( ping -q -w1 -c1 $PING_HOST > /dev/null ) ; do
    echo "Waiting for internet"
    sleep .5
done

echo "yum install -y ${PACKAGES[*]}"
until ( yum install -y ${PACKAGES[*]} > /dev/null ) ; do
    echo "yum failed to install packages. Trying again in 5 seconds"
    sleep 5
done

echo   "pip3 install --upgrade ${PY_PACKAGES[*]}"
until ( pip3 install --upgrade ${PY_PACKAGES[*]} ) ; do
    echo "pip3 failed to install python packages. Trying again in 5 seconds"
    sleep 5
done

SETUP_SCRIPT="setup.py"
SETUP_META="setup_script"
DIR="/tmp"
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
