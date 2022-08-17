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

variable "project_id" {
  type        = string
  description = "Project ID to create resources in."
}

variable "slurm_cluster_name" {
  type        = string
  description = "Cluster name, used for resource naming and slurm accounting."

  validation {
    condition     = can(regex("^[a-z](?:[a-z0-9]{0,9})$", var.slurm_cluster_name))
    error_message = "Variable 'slurm_cluster_name' must be a match of regex '^[a-z](?:[a-z0-9]{0,9})$'."
  }
}

#####################
# CONTROLLER: CLOUD #
#####################

variable "controller_instance_config" {
  description = <<EOD
Creates a controller instance with given configuration.
EOD
  type = object({
    access_config = list(object({
      nat_ip       = string
      network_tier = string
    }))
    additional_disks = list(object({
      disk_name    = string
      device_name  = string
      disk_size_gb = number
      disk_type    = string
      disk_labels  = map(string)
      auto_delete  = bool
      boot         = bool
    }))
    can_ip_forward         = bool
    disable_smt            = bool
    disk_auto_delete       = bool
    disk_labels            = map(string)
    disk_size_gb           = number
    disk_type              = string
    enable_confidential_vm = bool
    enable_oslogin         = bool
    enable_shielded_vm     = bool
    gpu = object({
      count = number
      type  = string
    })
    instance_template   = string
    labels              = map(string)
    machine_type        = string
    metadata            = map(string)
    min_cpu_platform    = string
    network_ip          = string
    on_host_maintenance = string
    preemptible         = bool
    region              = string
    service_account = object({
      email  = string
      scopes = list(string)
    })
    shielded_instance_config = object({
      enable_integrity_monitoring = bool
      enable_secure_boot          = bool
      enable_vtpm                 = bool
    })
    source_image_family  = string
    source_image_project = string
    source_image         = string
    static_ip            = string
    subnetwork_project   = string
    subnetwork           = string
    tags                 = list(string)
    zone                 = string
  })
  default = {
    access_config            = []
    additional_disks         = []
    can_ip_forward           = false
    disable_smt              = false
    disk_auto_delete         = true
    disk_labels              = {}
    disk_size_gb             = null
    disk_type                = null
    enable_confidential_vm   = false
    enable_oslogin           = true
    enable_shielded_vm       = false
    gpu                      = null
    instance_template        = null
    labels                   = {}
    machine_type             = "n1-standard-1"
    metadata                 = {}
    min_cpu_platform         = null
    network_ip               = null
    on_host_maintenance      = null
    preemptible              = false
    region                   = null
    service_account          = null
    shielded_instance_config = null
    source_image_family      = null
    source_image_project     = null
    source_image             = null
    static_ip                = null
    subnetwork_project       = null
    subnetwork               = "default"
    tags                     = []
    zone                     = null
  }
}

######################
# CONTROLLER: HYBRID #
######################

variable "enable_hybrid" {
  description = <<EOD
Enables use of hybrid controller mode. When true, controller_hybrid_config will
be used instead of controller_instance_config and will disable login instances.
EOD
  type        = bool
  default     = false
}

variable "controller_hybrid_config" {
  description = <<EOD
Creates a hybrid controller with given configuration.
See 'main.tf' for valid keys.
EOD
  type = object({
    google_app_cred_path = string
    slurm_control_host   = string
    slurm_bin_dir        = string
    slurm_log_dir        = string
    output_dir           = string
  })
  default = {
    google_app_cred_path = null
    slurm_control_host   = null
    slurm_bin_dir        = "/usr/local/bin"
    slurm_log_dir        = "/var/log/slurm"
    output_dir           = "/etc/slurm"
  }
}

#########
# LOGIN #
#########

variable "login_nodes" {
  description = "List of slurm login instance definitions."
  type = list(object({
    access_config = list(object({
      nat_ip       = string
      network_tier = string
    }))
    additional_disks = list(object({
      disk_name    = string
      device_name  = string
      disk_size_gb = number
      disk_type    = string
      disk_labels  = map(string)
      auto_delete  = bool
      boot         = bool
    }))
    can_ip_forward         = bool
    disable_smt            = bool
    disk_auto_delete       = bool
    disk_labels            = map(string)
    disk_size_gb           = number
    disk_type              = string
    enable_confidential_vm = bool
    enable_oslogin         = bool
    enable_shielded_vm     = bool
    gpu = object({
      count = number
      type  = string
    })
    group_name          = string
    instance_template   = string
    labels              = map(string)
    machine_type        = string
    metadata            = map(string)
    min_cpu_platform    = string
    network_ips         = list(string)
    num_instances       = number
    on_host_maintenance = string
    preemptible         = bool
    region              = string
    service_account = object({
      email  = string
      scopes = list(string)
    })
    shielded_instance_config = object({
      enable_integrity_monitoring = bool
      enable_secure_boot          = bool
      enable_vtpm                 = bool
    })
    source_image_family  = string
    source_image_project = string
    source_image         = string
    static_ips           = list(string)
    subnetwork_project   = string
    subnetwork           = string
    tags                 = list(string)
    zone                 = string
  }))
  default = []
}

#############
# PARTITION #
#############

variable "partitions" {
  description = <<EOD
Cluster partitions as a list. See module slurm_partition.
EOD
  type = list(object({
    enable_job_exclusive    = bool
    enable_placement_groups = bool
    partition_conf          = map(string)
    partition_startup_scripts = list(object({
      filename = string
      content  = string
    }))
    partition_name = string
    partition_nodes = list(object({
      node_count_static      = number
      node_count_dynamic_max = number
      group_name             = string
      node_conf              = map(string)
      additional_disks = list(object({
        disk_name    = string
        device_name  = string
        disk_size_gb = number
        disk_type    = string
        disk_labels  = map(string)
        auto_delete  = bool
        boot         = bool
      }))
      bandwidth_tier         = string
      can_ip_forward         = bool
      disable_smt            = bool
      disk_auto_delete       = bool
      disk_labels            = map(string)
      disk_size_gb           = number
      disk_type              = string
      enable_confidential_vm = bool
      enable_oslogin         = bool
      enable_shielded_vm     = bool
      enable_spot_vm         = bool
      gpu = object({
        count = number
        type  = string
      })
      instance_template   = string
      labels              = map(string)
      machine_type        = string
      metadata            = map(string)
      min_cpu_platform    = string
      on_host_maintenance = string
      preemptible         = bool
      service_account = object({
        email  = string
        scopes = list(string)
      })
      shielded_instance_config = object({
        enable_integrity_monitoring = bool
        enable_secure_boot          = bool
        enable_vtpm                 = bool
      })
      spot_instance_config = object({
        termination_action = string
      })
      source_image_family  = string
      source_image_project = string
      source_image         = string
      tags                 = list(string)
    }))
    network_storage = list(object({
      local_mount   = string
      fs_type       = string
      server_ip     = string
      remote_mount  = string
      mount_options = string
    }))
    region             = string
    subnetwork_project = string
    subnetwork         = string
    zone_policy_allow  = list(string)
    zone_policy_deny   = list(string)
  }))
  default = [
    {
      enable_job_exclusive    = false
      enable_placement_groups = false
      partition_conf = {
        Default = "YES"
      }
      partition_startup_scripts = []
      partition_name            = "debug"
      partition_nodes = [
        {
          node_count_static        = 20
          node_count_dynamic_max   = 0
          group_name               = "test"
          node_conf                = {}
          additional_disks         = []
          bandwidth_tier           = "platform_default"
          can_ip_forward           = false
          disable_smt              = false
          disk_auto_delete         = true
          disk_labels              = {}
          disk_size_gb             = null
          disk_type                = null
          enable_confidential_vm   = false
          enable_oslogin           = true
          enable_shielded_vm       = false
          enable_spot_vm           = false
          gpu                      = null
          instance_template        = null
          labels                   = {}
          machine_type             = "n1-standard-1"
          metadata                 = {}
          min_cpu_platform         = null
          on_host_maintenance      = null
          preemptible              = false
          service_account          = null
          shielded_instance_config = null
          spot_instance_config     = null
          source_image_family      = null
          source_image_project     = null
          source_image             = null
          tags                     = []
        }
      ]
      network_storage    = []
      region             = null
      subnetwork_project = null
      subnetwork         = "default"
      zone_policy_allow  = []
      zone_policy_deny   = []
    },
  ]

  validation {
    condition     = length(var.partitions) > 0
    error_message = "Partitions cannot be empty."
  }

  validation {
    condition = alltrue([
      for x in var.partitions : can(regex("^[a-z](?:[a-z0-9]{0,6})$", x.partition_name))
    ])
    error_message = "Items 'partition_name' must be a match of regex '^[a-z](?:[a-z0-9]{0,6})$'."
  }
}

#########
# SLURM #
#########

variable "enable_devel" {
  type        = bool
  description = "Enables development mode. Not for production use."
  default     = false
}

variable "enable_cleanup_compute" {
  description = <<EOD
Enables automatic cleanup of compute nodes and resource policies (e.g.
placement groups) managed by this module, when cluster is destroyed.

NOTE: Requires Python and script dependencies.

*WARNING*: Toggling this may impact the running workload. Deployed compute nodes
may be destroyed and their jobs will be requeued.
EOD
  type        = bool
  default     = false
}

variable "enable_cleanup_subscriptions" {
  description = <<EOD
Enables automatic cleanup of pub/sub subscriptions managed by this module, when
cluster is destroyed.

NOTE: Requires Python and script dependencies.

*WARNING*: Toggling this may temporarily impact var.enable_reconfigure behavior.
EOD
  type        = bool
  default     = false
}

variable "enable_reconfigure" {
  description = <<EOD
Enables automatic Slurm reconfigure on when Slurm configuration changes (e.g.
slurm.conf.tpl, partition details). Compute instances and resource policies
(e.g. placement groups) will be destroyed to align with new configuration.

NOTE: Requires Python and Google Pub/Sub API.

*WARNING*: Toggling this will impact the running workload. Deployed compute nodes
will be destroyed and their jobs will be requeued.
EOD
  type        = bool
  default     = false
}

variable "enable_bigquery_load" {
  description = <<EOD
Enables loading of cluster job usage into big query.

NOTE: Requires Google Bigquery API.
EOD
  type        = bool
  default     = false
}

variable "cloud_parameters" {
  description = "cloud.conf options."
  type = object({
    no_comma_params = bool
    resume_rate     = number
    resume_timeout  = number
    suspend_rate    = number
    suspend_timeout = number
  })
  default = {
    no_comma_params = false
    resume_rate     = 0
    resume_timeout  = 300
    suspend_rate    = 0
    suspend_timeout = 300
  }
}

variable "disable_default_mounts" {
  description = <<-EOD
    Disable default global network storage from the controller
    * /usr/local/etc/slurm
    * /etc/munge
    * /home
    * /apps
    If these are disabled, the slurm etc and munge dirs must be added manually,
    or some other mechanism must be used to synchronize the slurm conf files
    and the munge key across the cluster.
    EOD
  default     = false
}

variable "network_storage" {
  description = <<EOD
Storage to mounted on all instances.
* server_ip     : Address of the storage server.
* remote_mount  : The location in the remote instance filesystem to mount from.
* local_mount   : The location on the instance filesystem to mount to.
* fs_type       : Filesystem type (e.g. "nfs").
* mount_options : Options to mount with.
EOD
  type = list(object({
    server_ip     = string
    remote_mount  = string
    local_mount   = string
    fs_type       = string
    mount_options = string
  }))
  default = []
}

variable "login_network_storage" {
  description = <<EOD
Storage to mounted on login and controller instances
* server_ip     : Address of the storage server.
* remote_mount  : The location in the remote instance filesystem to mount from.
* local_mount   : The location on the instance filesystem to mount to.
* fs_type       : Filesystem type (e.g. "nfs").
* mount_options : Options to mount with.
EOD
  type = list(object({
    server_ip     = string
    remote_mount  = string
    local_mount   = string
    fs_type       = string
    mount_options = string
  }))
  default = []
}

variable "slurmdbd_conf_tpl" {
  description = "Slurm slurmdbd.conf template file path."
  type        = string
  default     = null
}

variable "slurm_conf_tpl" {
  description = "Slurm slurm.conf template file path."
  type        = string
  default     = null
}

variable "cgroup_conf_tpl" {
  description = "Slurm cgroup.conf template file path."
  type        = string
  default     = null
}

variable "controller_startup_scripts" {
  description = "List of scripts to be ran on controller VM startup."
  type = list(object({
    filename = string
    content  = string
  }))
  default = []
}

variable "login_startup_scripts" {
  description = "List of scripts to be ran on login VM startup."
  type = list(object({
    filename = string
    content  = string
  }))
  default = []
}

variable "compute_startup_scripts" {
  description = "List of scripts to be ran on compute VM startup."
  type = list(object({
    filename = string
    content  = string
  }))
  default = []
}

variable "prolog_scripts" {
  description = <<EOD
List of scripts to be used for Prolog. Programs for the slurmd to execute
whenever it is asked to run a job step from a new job allocation.
See https://slurm.schedmd.com/slurm.conf.html#OPT_Prolog.
EOD
  type = list(object({
    filename = string
    content  = string
  }))
  default = []
}

variable "epilog_scripts" {
  description = <<EOD
List of scripts to be used for Epilog. Programs for the slurmd to execute
on every node when a user's job completes.
See https://slurm.schedmd.com/slurm.conf.html#OPT_Epilog.
EOD
  type = list(object({
    filename = string
    content  = string
  }))
  default = []
}

variable "cloudsql" {
  description = <<EOD
Use this database instead of the one on the controller.
* server_ip : Address of the database server.
* user      : The user to access the database as.
* password  : The password, given the user, to access the given database. (sensitive)
* db_name   : The database to access.
EOD
  type = object({
    server_ip = string
    user      = string
    password  = string # sensitive
    db_name   = string
  })
  default   = null
  sensitive = true
}

variable "slurm_depends_on" {
  description = <<EOD
Custom terraform dependencies without replacement on delta. This is useful to
ensure order of resource creation.

NOTE: Also see terraform meta-argument 'depends_on'.
EOD
  type        = list(string)
  default     = []
}
