#!/bin/env bash

source ./functions.sh

add_slurm_user

setup_munge
setup_bash_profile

mount_nfs_vols

start_munge

install_slurm "$@"

setup_slurm_tmpfile
setup_slurm_units

setup_mariadb
systemctl enable slurmdbd
systemctl start slurmdbd

setup_nfs_threads
setup_nfs_exports /apps /home /etc/munge
systemctl enable nfs-server
systemctl start nfs-server
