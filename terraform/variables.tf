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

### General ###

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

### Network ###

variable "network" {
  type = object({
    subnetwork_project = string
    network            = string
    subnets            = list(string)
    subnets_regions    = list(string)
  })
}

### Configuration ###

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

### Controller ###

variable "controller" {
  type = object({
    ### multitude ###
    count_per_region      = number
    count_regions_covered = number

    ### network ###
    tags = list(string)

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
  })
  default = {
    additional_disks          = null
    count_per_region          = 0
    count_regions_covered     = 0
    disable_smt               = false
    disk_auto_delete          = false
    disk_labels               = null
    disk_size_gb              = null
    disk_type                 = null
    enable_confidential_vm    = false
    enable_shielded_vm        = false
    gpu                       = null
    instance_template         = null
    instance_template_project = null
    machine_type              = "n2d-standard-1"
    metadata                  = null
    min_cpu_platform          = null
    preemptible               = false
    service_account           = null
    shielded_instance_config  = null
    source_image              = null
    source_image_family       = null
    source_image_project      = null
    tags                      = null
  }
}

### Login ###

variable "login" {
  type = object({
    ### multitude ###
    count_per_region      = number
    count_regions_covered = number

    ### network ###
    tags = list(string)

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
  })
  default = {
    additional_disks          = null
    count_per_region          = 0
    count_regions_covered     = 0
    disable_smt               = false
    disk_auto_delete          = false
    disk_labels               = null
    disk_size_gb              = null
    disk_type                 = null
    enable_confidential_vm    = false
    enable_shielded_vm        = false
    gpu                       = null
    instance_template         = null
    instance_template_project = null
    machine_type              = "n2d-standard-1"
    metadata                  = null
    min_cpu_platform          = null
    preemptible               = false
    service_account           = null
    shielded_instance_config  = null
    source_image              = null
    source_image_family       = null
    source_image_project      = null
    tags                      = null
  }
}

### Compute ###

variable "compute" {
  type = map(object({
    ### network ###
    tags = list(string)

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
