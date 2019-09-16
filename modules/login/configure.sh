#!/bin/env bash

source ./functions.sh

add_slurm_user

setup_munge
setup_bash_profile
 
setup_nfs_vols $1 /apps /etc/munge
mount_nfs_vols

start_munge
