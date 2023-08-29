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

region             = "us-central1"
subnetwork         = "default"
subnetwork_project = null

source_image         = null
source_image_project = null
source_image_family  = null

enable_bigquery_load   = false
enable_cleanup_compute = true

# *NOT* intended for production use
# enable_devel = true

###########
# NETWORK #
###########

create_network = true

subnets = [
  {
    subnet_ip     = "10.0.0.0/24"
    subnet_region = "us-central1"
  },
]

mtu = 0

####################
# SERVICE ACCOUNTS #
####################

create_service_accounts = true

##########
# BUCKET #
##########

create_bucket = false

bucket_name = "<BUCKET_NAME>"

bucket_dir = null

#################
# CONFIGURATION #
#################

# cloudsql = {
#   server_ip = "<SERVER_IP>:<PORT>"
#   user      = "<USERNAME>"
#   password  = "<PASSWORD>"
#   db_name   = "<DB_NAME>"
# }

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
  resume_rate     = 0
  resume_timeout  = 300
  suspend_rate    = 0
  suspend_timeout = 300
}

# scripts
controller_startup_scripts_timeout = 300
controller_startup_scripts = [
  #   {
  #     filename = "hello_controller.sh"
  #     content  = <<EOF
  # #!/bin/bash
  # set -ex
  # echo "Hello, $(hostname) from $(dirname $0) !"
  #     EOF
  #   },
]
login_startup_scripts_timeout = 300
login_startup_scripts = [
  #   {
  #     filename = "hello_login.sh"
  #     content  = <<EOF
  # #!/bin/bash
  # set -ex
  # echo "Hello, $(hostname) from $(dirname $0) !"
  #     EOF
  #   },
]
compute_startup_scripts_timeout = 300
compute_startup_scripts = [
  #   {
  #     filename = "hello_compute.sh"
  #     content  = <<EOF
  # #!/bin/bash
  # set -ex
  # echo "Hello, $(hostname) from $(dirname $0) !"
  #       EOF
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
  #       EOF
  #   },
]

##############
# CONTROLLER #
##############

controller_instance_config = {
  # Template By Definition
  additional_disks = [
    # {
    #   disk_name    = null
    #   device_name  = null
    #   disk_size_gb = 128
    #   disk_type    = "pd-standard"
    #   disk_labels  = {}
    #   auto_delete  = true
    #   boot         = false
    # },
  ]
  bandwidth_tier   = "platform_default"
  can_ip_forward   = null
  disable_smt      = false
  disk_auto_delete = true
  disk_labels = {
    # label0 = "value0"
    # label1 = "value1"
  }
  disk_size_gb           = 32
  disk_type              = "pd-ssd"
  enable_confidential_vm = false
  enable_oslogin         = true
  enable_shielded_vm     = false
  gpu                    = null
  labels = {
    # label0 = "value0"
    # label1 = "value1"
  }
  machine_type = "n1-standard-4"
  metadata = {
    # metadata0 = "value0"
    # metadata1 = "value1"
  }
  min_cpu_platform    = null
  on_host_maintenance = null
  preemptible         = false
  service_account = {
    email  = null
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
  shielded_instance_config = {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
    enable_vtpm                 = true
  }
  source_image_family  = null
  source_image_project = null
  source_image         = null
  spot                 = false
  tags = [
    # "tag0",
    # "tag1",
  ]
  termination_action = null

  # Template By Source
  instance_template = null

  # Instance Definition
  enable_public_ip   = false
  network_ips        = "STANDARD"
  network_ip         = null
  region             = null
  static_ip          = null
  subnetwork_project = null
  subnetwork         = null
  zone               = null
}

##########
# HYBRID #
##########

enable_hybrid = false

controller_hybrid_config = {
  google_app_cred_path    = null
  slurm_control_host      = "<CONTROLLER>"
  slurm_control_host_port = "6817"
  slurm_control_addr      = null
  slurm_bin_dir           = "/usr/local/bin"
  slurm_log_dir           = "./log"
  output_dir              = "./etc"
  install_dir             = null
  munge_mount = {
    server_ip     = "<CONTROLLER>"
    remote_mount  = "/etc/munge"
    fs_type       = "nfs"
    mount_options = ""
  }
}

#########
# LOGIN #
#########

enable_login = true

login_nodes = [
  {
    # Group Definition
    group_name = "l0"

    # Template By Definition
    additional_disks       = []
    bandwidth_tier         = "platform_default"
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
    machine_type           = "n1-standard-2"
    metadata               = {}
    min_cpu_platform       = null
    on_host_maintenance    = null
    preemptible            = false
    service_account = {
      email = null
      scopes = [
        "https://www.googleapis.com/auth/cloud-platform",
      ]
    }
    shielded_instance_config = null
    source_image_family      = null
    source_image_project     = null
    source_image             = null
    spot                     = false
    tags                     = []
    termination_action       = null

    # Template By Source
    instance_template = null

    # Instance Definition
    enable_public_ip   = false
    network_ips        = "STANDARD"
    num_instances      = 1
    region             = null
    static_ips         = []
    subnetwork_project = null
    subnetwork         = null
    zone               = null
  },
]

############
# NODESETS #
############

nodeset = []

nodeset_dyn = []

nodeset_tpu = [
  {
    # Group Definition
    nodeset_name           = "v2x8tf121"
    tf_version             = "2.12.1"
    node_count_dynamic_max = 5
    node_count_static      = 0
    node_type              = "v2-8"

    zone = "us-central1-b"

    # Options
    preemptible  = true
    preserve_tpu = true
  },
]

##############
# PARTITIONS #
##############

partitions = [
  {

    partition_name        = "tpu121"
    partition_nodeset_tpu = ["v2x8tf121", ]
    # partition_nodeset = [ "n1s1" ]
    # Options
    resume_timeout  = 600
    suspend_time    = 600
    suspend_timeout = 240
  },
]
