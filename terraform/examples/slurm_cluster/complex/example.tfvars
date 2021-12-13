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

cluster_name = "complex"

region = "<REGION>"

# *NOT* intended for production use
# enable_devel = true

#################
# CONFIGURATION #
#################

### setup ###
cloudsql  = null
jwt_key   = null
munge_key = null

### storage ###
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

### slurm config ###
cgroup_conf_tpl   = null
slurm_conf_tpl    = null
slurmdbd_conf_tpl = null
cloud_parameters = {
  ResumeRate     = 0
  ResumeTimeout  = 300
  SuspendRate    = 0
  SuspendTimeout = 300
}

### scripts.d ###
controller_d = null
compute_d    = null

##############
# CONTROLLER #
##############

### Service Account ###

controller_service_account = {
  email = "default"
  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
  ]
}

### Templates ###

controller_template = {
  ### network ###
  subnetwork = "default"
  region     = "us-east1"
  tags = [
    # "tag0",
    # "tag1",
  ]

  ### template ###
  instance_template_project = null
  instance_template         = null

  ### instance ###
  machine_type     = "n2d-standard-4"
  min_cpu_platform = null
  gpu              = null
  shielded_instance_config = {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  enable_confidential_vm = false
  enable_shielded_vm     = false
  disable_smt            = false
  preemptible            = false
  labels = {
    # label0 = "value0"
    # label1 = "value1"
  }

  ### image ###
  source_image_project = ""
  source_image_family  = ""
  source_image         = ""

  ### disk ###
  disk_labels = {
    # label0 = "value0"
    # label1 = "value1"
  }
  disk_size_gb     = 32
  disk_type        = "pd-ssd"
  disk_auto_delete = true
  additional_disks = [
    # {
    #   disk_name    = null
    #   device_name  = null
    #   disk_size_gb = 1024
    #   disk_type    = "pd-standard"
    #   disk_labels  = null
    #   auto_delete  = true
    #   boot         = false
    # },
  ]
}

#########
# LOGIN #
#########

### Service Account ###

login_service_account = {
  email = "default"
  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
  ]
}

login = [
  {
    alias         = "login"
    num_instances = 1

    ### network ###
    subnetwork = "default"
    region     = "us-east1"
    tags = [
      # "tag0",
      # "tag1",
    ]

    ### template ###
    instance_template_project = null
    instance_template         = null

    ### instance ###
    machine_type     = "n1-standard-2"
    min_cpu_platform = null
    gpu              = null
    shielded_instance_config = {
      enable_secure_boot          = true
      enable_vtpm                 = true
      enable_integrity_monitoring = true
    }
    enable_confidential_vm = false
    enable_shielded_vm     = false
    disable_smt            = false
    preemptible            = false
    labels = {
      # label0 = "value0"
      # label1 = "value1"
    }

    ### image ###
    source_image_project = ""
    source_image_family  = ""
    source_image         = ""

    ### disk ###
    disk_labels = {
      # label0 = "value0"
      # label1 = "value1"
    }
    disk_size_gb     = 32
    disk_type        = "pd-ssd"
    disk_auto_delete = true
    additional_disks = [
      # {
      #   disk_name    = null
      #   device_name  = null
      #   disk_size_gb = 1024
      #   disk_type    = "pd-standard"
      #   disk_labels  = null
      #   auto_delete  = true
      #   boot         = false
      # },
    ]
  },
]

###########
# COMPUTE #
###########

### Service Account ###

compute_service_account = {
  email = "default"
  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
  ]
}

### Templates ###

compute_templates = [
  {
    alias = "cpu"

    ### network ###
    tags = [
      # "tag0",
      # "tag1",
    ]

    ### instance ###
    machine_type     = "n1-standard-1"
    min_cpu_platform = null
    gpu              = null
    shielded_instance_config = {
      enable_secure_boot          = true
      enable_vtpm                 = true
      enable_integrity_monitoring = true
    }
    enable_confidential_vm = false
    enable_shielded_vm     = false
    disable_smt            = false
    preemptible            = false
    labels = {
      # label0 = "value0"
      # label1 = "value1"
    }

    ### image ###
    source_image_project = ""
    source_image_family  = ""
    source_image         = ""

    ### disk ###
    disk_labels = {
      # "label0" = "value0"
      # "label1" = "value1"
    }
    disk_size_gb     = 32
    disk_type        = "pd-ssd"
    disk_auto_delete = true
    additional_disks = [
      # {
      #   disk_name    = null
      #   device_name  = null
      #   disk_size_gb = 1024
      #   disk_type    = "pd-standard"
      #   disk_labels  = null
      #   auto_delete  = true
      #   boot         = false
      # },
    ]
  },
  {
    alias = "gpu"

    ### network ###
    tags = [
      # "tag0",
      # "tag1",
    ]

    ### instance ###
    machine_type     = "n1-standard-4"
    min_cpu_platform = null
    gpu              = null
    gpu = {
      type  = "nvidia-tesla-t4"
      count = 1
    }
    shielded_instance_config = {
      enable_secure_boot          = true
      enable_vtpm                 = true
      enable_integrity_monitoring = true
    }
    enable_confidential_vm = false
    enable_shielded_vm     = false
    disable_smt            = false
    preemptible            = false
    labels = {
      # label0 = "value0"
      # label1 = "value1"
    }

    ### image ###
    source_image_project = ""
    source_image_family  = ""
    source_image         = ""

    ### disk ###
    disk_labels = {
      # "label0" = "value0"
      # "label1" = "value1"
    }
    disk_size_gb     = 32
    disk_type        = "pd-ssd"
    disk_auto_delete = true
    additional_disks = [
      # {
      #   disk_name    = null
      #   device_name  = null
      #   disk_size_gb = 1024
      #   disk_type    = "pd-standard"
      #   disk_labels  = null
      #   auto_delete  = true
      #   boot         = false
      # },
    ]
  }
]

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
    partition_nodes = [
      {
        node_group_name            = "n1"
        compute_template_alias_ref = "cpu"
        count_static               = 0
        count_dynamic              = 20
      },
      {
        node_group_name            = "tesla"
        compute_template_alias_ref = "gpu"
        count_static               = 0
        count_dynamic              = 5
      },
    ]
    zone_policy_allow = []
    zone_policy_deny  = []
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
