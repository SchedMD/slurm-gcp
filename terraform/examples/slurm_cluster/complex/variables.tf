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

variable "project_id" {
  type        = string
  description = "Project ID to create resources in."
}

variable "cluster_name" {
  type        = string
  description = "Cluster name, used for resource naming."
  default     = "complex"
}

variable "enable_devel" {
  type        = bool
  description = "Enables development process for faster iterations. NOTE: *NOT* intended for production use."
  default     = false
}

###########
# NETWORK #
###########

variable "region" {
  type        = string
  description = "The region to place resources in."
}

#################
# CONFIGURATION #
#################

variable "config" {
  ### setup ###
  type = object({
    cloud_parameters = map(string)
    cloudsql = object({
      server_ip = string
      user      = string
      password  = string # (sensitive)
      db_name   = string
    })
    jwt_key   = string
    munge_key = string

    ### storage ###
    network_storage = list(object({
      server_ip     = string
      remote_mount  = string
      local_mount   = string
      fs_type       = string
      mount_options = string
    }))
    login_network_storage = list(object({
      server_ip     = string
      remote_mount  = string
      local_mount   = string
      fs_type       = string
      mount_options = string
    }))

    ### slurm conf files ###
    cgroup_conf_tpl   = string
    slurm_conf_tpl    = string
    slurmdbd_conf_tpl = string

    ### scripts.d ###
    controller_d = string
    compute_d    = string
  })
  description = "General cluster configuration."
  sensitive   = true
  default = {
    cloud_parameters      = {}
    cgroup_conf_tpl       = null
    cloudsql              = null
    compute_d             = null
    controller_d          = null
    jwt_key               = null
    login_network_storage = null
    munge_key             = null
    network_storage       = null
    slurm_conf_tpl        = null
    slurmdbd_conf_tpl     = null
  }
}

##############
# CONTROLLER #
##############

variable "controller_service_account" {
  type = object({
    email  = string
    scopes = set(string)
  })
  description = "Service account to attach to the instance. See https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#service_account."
  default = {
    email  = null
    scopes = null
  }
}

variable "controller_template" {
  type = object({
    ### network ###
    tags = list(string)

    ### instance ###
    machine_type     = string
    min_cpu_platform = string
    gpu = object({
      type  = string
      count = number
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
    labels                 = map(string)

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
  description = "Slurm controller template."
}

#########
# LOGIN #
#########

variable "login_service_account" {
  type = object({
    email  = string
    scopes = set(string)
  })
  description = "Service account to attach to the instance. See https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#service_account."
  default = {
    email  = null
    scopes = null
  }
}

variable "login_templates" {
  type = map(object({
    ### network ###
    tags = list(string)

    ### instance ###
    machine_type     = string
    min_cpu_platform = string
    gpu = object({
      type  = string
      count = number
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
    labels                 = map(string)

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
  description = "Maps slurm login template name to instance definition."
  default     = {}
}

variable "login_instances" {
  type = list(object({
    template = string
    count    = number
  }))
  description = "Instantiates login node(s) from slurm 'login_template'."
  default     = []
}

###########
# COMPUTE #
###########

variable "compute_service_account" {
  type = object({
    email  = string
    scopes = set(string)
  })
  description = "Service account to attach to the instance. See https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#service_account."
  default = {
    email  = null
    scopes = null
  }
}

variable "compute_templates" {
  type = map(object({
    ### network ###
    tags = list(string)

    ### instance ###
    machine_type     = string
    min_cpu_platform = string
    gpu = object({
      type  = string
      count = number
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
    labels                 = map(string)

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
  description = "Maps slurm compute template name to instance definition."
  default     = {}
}

##############
# PARTITIONS #
##############

variable "partitions" {
  type = map(object({
    zone_policy = map(string)
    nodes = list(object({
      template      = string
      count_static  = number
      count_dynamic = number
    }))
    network_storage = list(object({
      server_ip     = string
      remote_mount  = string
      local_mount   = string
      fs_type       = string
      mount_options = string
    }))
    exclusive        = bool
    placement_groups = bool
    conf             = map(string)
  }))
  description = "Cluster partition configuration."
  default     = {}
}
