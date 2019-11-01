#!/bin/bash

PACKAGES=(
        'bind-utils'
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
        'python-pip'
        'readline-devel'
        'rpm-build'
        'rrdtool-devel'
        'vim'
        'wget'
        'tmux'
        'pdsh'
        'openmpi'
    )

PY_PACKAGES=(
        'pyyaml'
        'google-api-python-client'
    )

PING_HOST=8.8.8.8
until ( ping -q -w1 -c1 $PING_HOST > /dev/null ) ; do
    echo "Waiting for internet"
    sleep .5
done

until ( yum install -y ${PACKAGES[*]} ) ; do
    echo "yum failed to install packages. Trying again in 5 seconds"
    sleep 5
done

until ( pip install --upgrade ${PY_PACKAGES[*]} ) ; do
    echo "pip failed to install python packages. Trying again in 5 seconds"
    sleep 5
done

SETUP_SCRIPT="setup.py"
SETUP_META="setup_script"
DIR="/tmp"
URL="http://metadata.google.internal/computeMetadata/v1/instance/attributes/$SETUP_META"
HEADER="Metadata-Flavor:Google"
if ! ( wget --header $HEADER $URL -O $DIR/$SETUP_SCRIPT ) ; then
    echo "Failed to fetch $SETUP_META:$SETUP_SCRIPT from metadata"
    exit 1
fi

echo "running python cluster setup script"
/usr/bin/env python2 $DIR/$SETUP_SCRIPT
