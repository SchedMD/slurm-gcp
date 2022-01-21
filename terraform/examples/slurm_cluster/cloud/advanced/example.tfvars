/**
 * Copyright 2021 SchedMD LLC
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

cluster_name = "advanced-cloud"

region = "<REGION>"

# *NOT* intended for production use
# enable_devel = true

#################
# CONFIGURATION #
#################

firewall_network_name = "default"

cloudsql  = null
jwt_key   = null
munge_key = null

# Network storage
network_storage = [
  # {
  #   server_ip     = "<storage host>"
  #   remote_mount  = "/home"
  #   local_mount   = "/home"
  #   fs_type       = "nfs"
  #   mount_options = null
  # },
]
login_network_storage = [
  # {
  #   server_ip     = "<storage host>"
  #   remote_mount  = "/net_storage"
  #   local_mount   = "/shared"
  #   fs_type       = "nfs"
  #   mount_options = null
  # },
]

# Slurm config
cgroup_conf_tpl   = null
slurm_conf_tpl    = null
slurmdbd_conf_tpl = null
cloud_parameters = {
  ResumeRate     = 0
  ResumeTimeout  = 300
  SuspendRate    = 0
  SuspendTimeout = 300
}

# scripts.d
controller_d = [
  #   {
  #     filename = "hello_controller.sh"
  #     content  = <<EOF
  # #!/bin/bash
  # set -ex
  # echo "Hello, $(hostname) !"
  #     EOF
  #   },
]
compute_d = [
  #   {
  #     filename = "hello_compute.sh"
  #     content  = <<EOF
  # #!/bin/bash
  # set -ex
  # echo "Hello, $(hostname) !"
  #       EOF
  #   },
]

############
# DEFAULTS #
############

slurm_cluster_defaults = {
  additional_disks = [
    # {
    #   disk_name    = null
    #   device_name  = null
    #   disk_size_gb = 1024
    #   disk_type    = "pd-standard"
    #   disk_labels  = {}
    #   auto_delete  = true
    #   boot         = false
    # },
  ]
  can_ip_forward   = null
  disable_smt      = false
  disk_auto_delete = true
  disk_labels = {
    # label0 = "value0"
    # label1 = "value1"
  }
  disk_size_gb           = "32"
  disk_type              = "pd-standard"
  enable_confidential_vm = false
  enable_oslogin         = true
  enable_shielded_vm     = false
  gpu                    = null
  labels = {
    # label0 = "value0"
    # label1 = "value1"
  }
  machine_type        = "n1-standard-1"
  metadata            = {}
  min_cpu_platform    = null
  network_ip          = ""
  network             = null
  on_host_maintenance = null
  preemptible         = false
  region              = null
  service_account = {
    email  = "default"
    scopes = []
  }
  shielded_instance_config = {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
    enable_vtpm                 = true
  }
  source_image_family  = ""
  source_image_project = ""
  source_image         = ""
  subnetwork_project   = null
  subnetwork           = "default"
  tags = [
    # "tag0",
    # "tag1",
  ]
  zone = null
}

##############
# CONTROLLER #
##############

# See 'slurm_cluster_defaults' for valid key/value
controller_instance_config = {
  disk_size_gb       = "32"
  disk_type          = "pd-ssd"
  enable_shielded_vm = true
  machine_type       = "n2d-standard-4"
  service_account = {
    email = "default"
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

#########
# LOGIN #
#########

# See 'slurm_cluster_defaults' for valid key/value
login_node_groups_defaults = {
  enable_shielded_vm = true
  service_account = {
    email = "default"
    scopes = [
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/logging.write",
    ]
  }
}

# See 'slurm_cluster_defaults' for valid key/value
login_node_groups = [
  {
    group_name    = "l0"
    num_instances = 1

    disk_size_gb = 32
    disk_type    = "pd-standard"
    machine_type = "n1-standard-2"
  },
]

###########
# COMPUTE #
###########

# See 'slurm_cluster_defaults' for valid key/value
compute_node_groups_defaults = {
  disk_size_gb       = 32
  disk_type          = "pd-standard"
  enable_shielded_vm = true
  machine_type       = "n1-standard-4"
  service_account = {
    email = "default"
    scopes = [
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/logging.write",
    ]
  }
}

##############
# PARTITIONS #
##############

partitions = [
  {
    partition_name = "debug"
    partition_conf = {
      Default     = "YES"
      SuspendTime = 300
    }
    partition_d = [
      #     {
      #       filename = "hello_partition.sh"
      #       content  = <<EOF
      # #!/bin/bash
      # set -ex
      # echo "Hello, $(hostname) !"
      #     EOF
      #     },
    ]
    # See 'slurm_cluster_defaults' for valid key/value
    compute_node_groups = [
      {
        group_name    = "c0"
        count_static  = 0
        count_dynamic = 20

        disk_size_gb = 32
        disk_type    = "pd-standard"
        machine_type = "n1-standard-1"
        disable_smt  = false
        preemptible  = false
      },
      {
        group_name    = "g0"
        count_static  = 0
        count_dynamic = 10

        disk_size_gb = 32
        disk_type    = "pd-standard"
        machine_type = "n1-standard-1"
        gpu = {
          type  = "nvidia-tesla-t4"
          count = 1
        }
        enable_shielded_vm = false
      },
    ]
    subnetwork_project = null
    subnetwork         = "default"
    region             = null
    zone_policy_allow  = []
    zone_policy_deny   = []
    network_storage = [
      # {
      #   server_ip     = "<storage host>"
      #   remote_mount  = "/net_storage"
      #   local_mount   = "/shared"
      #   fs_type       = "nfs"
      #   mount_options = null
      # },
    ]
    enable_job_exclusive    = false
    enable_placement_groups = false
  },
]
