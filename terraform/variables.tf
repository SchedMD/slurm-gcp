# Copyright 2021 SchedMD LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

###########
# GENERAL #
###########

variable "project_id" {
  type        = string
  description = "Project ID to create resources in."
}

variable "cluster_name" {
  type        = string
  description = "Cluster name used for accounting and resource naming."
}

variable "enable_devel" {
  type        = bool
  description = "Enables development process for faster iterations. NOTE: *NOT* intended for production use."
  default     = false
}

###########
# NETWORK #
###########

variable "network" {
  type = object({
    ### attach ###
    subnetwork_project = string
    network            = string
    subnets = list(object({
      name   = string
      region = string
    }))

    ### generate ###
    auto_create_subnetworks = bool
    subnets_spec = list(object({
      cidr   = string
      region = string
    }))
  })
  default = {
    auto_create_subnetworks = true
    network                 = null
    subnets                 = null
    subnets_spec            = null
    subnetwork_project      = null
  }
}

#################
# CONFIGURATION #
#################

variable "config" {
  ### setup ###
  type = object({
    cloudsql = object({
      server_ip = string
      user      = string
      password  = string # sensitive
      db_name   = string
    })
    jwt_key   = string
    munge_key = string

    ### storage ###
    # network_storage: mounted on all instances
    network_storage = list(object({
      server_ip     = string
      remote_mount  = string
      local_mount   = string
      fs_type       = string
      mount_options = string
    }))
    # login_network_storage: mounted on login and controller
    login_network_storage = list(object({
      server_ip     = string
      remote_mount  = string
      local_mount   = string
      fs_type       = string
      mount_options = string
    }))

    ### slurm.conf ###
    suspend_time = number
  })
  sensitive = true
  default = {
    cloudsql              = null
    jwt_key               = null
    login_network_storage = null
    munge_key             = null
    network_storage       = null
    suspend_time          = null
  }
}

##############
# CONTROLLER #
##############

variable "controller_templates" {
  type = map(object({
    ### network ###
    subnet_name   = string
    subnet_region = string
    tags          = list(string)

    ### template ###
    instance_template_project = string
    instance_template         = string

    ### instance ###
    machine_type     = string
    min_cpu_platform = string
    gpu = object({
      type  = string
      count = number
    })
    service_account = object({
      email  = string
      scopes = set(string)
    })
    shielded_instance_config = object({
      enable_secure_boot          = bool
      enable_vtpm                 = bool
      enable_integrity_monitoring = bool
    })
    enable_confidential_vm = bool
    enable_shielded_vm     = bool
    disable_smt            = bool
    preemptible            = bool

    ### metadata ###
    metadata = map(string)

    ### source image ###
    source_image_project = string
    source_image_family  = string
    source_image         = string

    ### disk ###
    disk_type        = string
    disk_size_gb     = number
    disk_labels      = map(string)
    disk_auto_delete = bool
    additional_disks = list(object({
      disk_name    = string
      device_name  = string
      auto_delete  = bool
      boot         = bool
      disk_size_gb = number
      disk_type    = string
      disk_labels  = map(string)
    }))
  }))
  default = {}
}

variable "controller_instances" {
  type = list(object({
    template      = string # must match a key in 'controller_templates'
    count_static  = number
    subnet_name   = string
    subnet_region = string
  }))
  default = []
}

#########
# LOGIN #
#########

variable "login_templates" {
  type = map(object({
    ### network ###
    subnet_name   = string
    subnet_region = string
    tags          = list(string)

    ### template ###
    instance_template_project = string
    instance_template         = string

    ### instance ###
    machine_type     = string
    min_cpu_platform = string
    gpu = object({
      type  = string
      count = number
    })
    service_account = object({
      email  = string
      scopes = set(string)
    })
    shielded_instance_config = object({
      enable_secure_boot          = bool
      enable_vtpm                 = bool
      enable_integrity_monitoring = bool
    })
    enable_confidential_vm = bool
    enable_shielded_vm     = bool
    disable_smt            = bool
    preemptible            = bool

    ### metadata ###
    metadata = map(string)

    ### source image ###
    source_image_project = string
    source_image_family  = string
    source_image         = string

    ### disk ###
    disk_type        = string
    disk_size_gb     = number
    disk_labels      = map(string)
    disk_auto_delete = bool
    additional_disks = list(object({
      disk_name    = string
      device_name  = string
      auto_delete  = bool
      boot         = bool
      disk_size_gb = number
      disk_type    = string
      disk_labels  = map(string)
    }))
  }))
  default = {}
}

variable "login_instances" {
  type = list(object({
    template      = string # must match a key in 'login_templates'
    count_static  = number
    subnet_name   = string
    subnet_region = string
  }))
  default = []
}

###########
# COMPUTE #
###########

variable "compute_templates" {
  type = map(object({
    ### network ###
    subnet_name   = string
    subnet_region = string
    tags          = list(string)

    ### template ###
    instance_template_project = string
    instance_template         = string

    ### instance ###
    machine_type     = string
    min_cpu_platform = string
    gpu = object({
      type  = string
      count = number
    })
    service_account = object({
      email  = string
      scopes = set(string)
    })
    shielded_instance_config = object({
      enable_secure_boot          = bool
      enable_vtpm                 = bool
      enable_integrity_monitoring = bool
    })
    enable_confidential_vm = bool
    enable_shielded_vm     = bool
    disable_smt            = bool
    preemptible            = bool

    ### metadata ###
    metadata = map(string)

    ### source image ###
    source_image_project = string
    source_image_family  = string
    source_image         = string

    ### disk ###
    disk_type        = string
    disk_size_gb     = number
    disk_labels      = map(string)
    disk_auto_delete = bool
    additional_disks = list(object({
      disk_name    = string
      device_name  = string
      auto_delete  = bool
      boot         = bool
      disk_size_gb = number
      disk_type    = string
      disk_labels  = map(string)
    }))
  }))
  default = {}
}

##############
# PARTITIONS #
##############

variable "partitions" {
  type = map(object({
    nodes = list(object({
      template      = string # must match a key in 'compute_templates'
      count_static  = number
      count_dynamic = number
      subnet_name   = string
      subnet_region = string
    }))
    conf = map(string)
  }))
  default = {}
}
