/**
 * Copyright (C) SchedMD LLC.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

###########
# GENERAL #
###########

project_id = "<PROJECT_ID>"

slurm_cluster_name = "basic"

region = "us-central1"

# *NOT* intended for production use
# enable_devel = true

enable_bigquery_load         = false
enable_cleanup_compute       = true
enable_cleanup_subscriptions = false
enable_reconfigure           = false

#################
# CONFIGURATION #
#################

# Slurm config
cloud_parameters = {
  no_comma_params = false
  resume_rate     = 0
  resume_timeout  = 300
  suspend_rate    = 0
  suspend_timeout = 300
}

# Network storage
# hybrid requires synchronizing the slurm.conf directory and the munge.key from the controller
disable_default_mounts = true
network_storage = [
  # {
  #   server_ip     = "<storage host>"
  #   remote_mount  = "/home"
  #   local_mount   = "/home"
  #   fs_type       = "nfs"
  #   mount_options = null
  # },
]

# scripts
compute_startup_scripts = [
  #   {
  #     filename = "hello_compute.sh"
  #     content  = <<EOF
  # #!/bin/bash
  # set -ex
  # echo "Hello, $(hostname) from $(dirname $0) !"
  #     EOF
  #   },
]
prolog_scripts = [
  #   {
  #     filename = "hello_prolog.sh"
  #     content  = <<EOF
  # #!/bin/bash
  # set -ex
  # echo "Hello, $(hostname) from $(dirname $0) !"
  #     EOF
  #   },
]
epilog_scripts = [
  #   {
  #     filename = "hello_epilog.sh"
  #     content  = <<EOF
  # #!/bin/bash
  # set -ex
  # echo "Hello, $(hostname) from $(dirname $0) !"
  #     EOF
  #   },
]

##############
# CONTROLLER #
##############

controller_hybrid_config = {
  google_app_cred_path = null
  slurm_control_host   = null
  slurm_bin_dir        = "/usr/local/bin"
  slurm_log_dir        = "./log"
  output_dir           = "./etc"
}

##############
# PARTITIONS #
##############

partitions = [
  {
    enable_job_exclusive    = false
    enable_placement_groups = false
    network_storage         = []
    partition_conf = {
      ResumeTimeout  = 300
      SuspendTimeout = 300
      SuspendTime    = 300
    }
    partition_startup_scripts = [
      # {
      #   filename = "hello_part_debug.sh"
      #   content  = <<EOF
      # #!/bin/bash
      # set -ex
      # echo "Hello, $(hostname) from $(dirname $0) !"
      #   EOF
      # },
    ]
    partition_name = "debug"
    partition_nodes = [
      {
        # Group Definition
        group_name             = "test"
        node_count_dynamic_max = 20
        node_count_static      = 0
        node_conf = {
          Features = "test"
        }

        # Template By Definition
        additional_disks       = []
        can_ip_forward         = false
        disable_smt            = false
        disk_auto_delete       = true
        disk_labels            = {}
        disk_size_gb           = 32
        disk_type              = "pd-standard"
        enable_confidential_vm = false
        enable_oslogin         = true
        enable_shielded_vm     = false
        gpu                    = null
        labels                 = {}
        machine_type           = "c2-standard-4"
        metadata               = {}
        min_cpu_platform       = null
        on_host_maintenance    = null
        preemptible            = false
        service_account = {
          email = "default"
          scopes = [
            "https://www.googleapis.com/auth/cloud-platform",
          ]
        }
        shielded_instance_config = null
        source_image_family      = null
        source_image_project     = null
        source_image             = null
        tags                     = []

        # Template By Source
        instance_template = null

        # Instance Definition
        bandwidth_tier = "platform_default"
        enable_spot_vm = false
        spot_instance_config = {
          termination_action = "STOP"
        }
      },
    ]
    region             = null
    subnetwork_project = null
    subnetwork         = "default"
    zone_policy_allow  = []
    zone_policy_deny   = []
  },
  {
    enable_job_exclusive    = false
    enable_placement_groups = false
    network_storage         = []
    partition_conf = {
      ResumeTimeout  = 300
      SuspendTimeout = 300
      SuspendTime    = 300
    }
    partition_startup_scripts = []
    partition_name            = "debug2"
    partition_nodes = [
      {
        # Group Definition
        group_name             = "test"
        node_count_dynamic_max = 10
        node_count_static      = 0
        node_conf              = {}

        # Template By Definition
        additional_disks       = []
        can_ip_forward         = false
        disable_smt            = false
        disk_auto_delete       = true
        disk_labels            = {}
        disk_size_gb           = 32
        disk_type              = "pd-standard"
        enable_confidential_vm = false
        enable_oslogin         = true
        enable_shielded_vm     = false
        gpu = {
          count = 1
          type  = "nvidia-tesla-v100"
        }
        labels              = {}
        machine_type        = "n1-standard-4"
        metadata            = {}
        min_cpu_platform    = null
        on_host_maintenance = null
        preemptible         = false
        service_account = {
          email = "default"
          scopes = [
            "https://www.googleapis.com/auth/cloud-platform",
          ]
        }
        shielded_instance_config = null
        source_image_family      = null
        source_image_project     = null
        source_image             = null
        tags                     = []

        # Template By Source
        instance_template = null

        # Instance Definition
        bandwidth_tier = "platform_default"
        enable_spot_vm = false
        spot_instance_config = {
          termination_action = "STOP"
        }
      },
    ]
    region             = null
    subnetwork_project = null
    subnetwork         = "default"
    zone_policy_allow  = []
    zone_policy_deny   = []
  },
]
