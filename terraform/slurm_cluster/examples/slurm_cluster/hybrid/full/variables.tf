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
  description = "Cluster name, used for resource naming."
  default     = "full"
}

variable "enable_devel" {
  type        = bool
  description = <<EOD
Enables development mode.

NOTE: *NOT* intended for production use.
EOD
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

variable "region" {
  type        = string
  description = "The default region to place resources in."
}

###########
# NETWORK #
###########

variable "subnets" {
  type        = list(map(string))
  description = "The list of subnets being created."
  default     = []

  validation {
    condition     = length(var.subnets) > 0
    error_message = "Subnets cannot be an empty list."
  }
}

variable "mtu" {
  type        = number
  description = <<EOD
The network MTU. Must be a value between 1460 and 1500 inclusive. If set to 0
(meaning MTU is unset), the network will default to 1460 automatically.
EOD
  default     = 0
}

#################
# CONFIGURATION #
#################

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

##############
# CONTROLLER #
##############

variable "controller_hybrid_config" {
  description = <<EOD
Creates a hybrid controller with given configuration.

Variables map to:
- [slurm_controller_hybrid](../../../../modules/slurm_controller_hybrid/README_TF.md#inputs)
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
    output_dir           = "."
  }
}

##############
# PARTITIONS #
##############

variable "partitions" {
  description = <<EOD
Cluster partition configuration as a list.

Variables map to:
- [slurm_partition](../../../../modules/slurm_partition/README_TF.md#inputs)
- [slurm_instance_template](../../../../modules/slurm_instance_template/README_TF.md#inputs)
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
    region            = string
    zone_policy_allow = list(string)
    zone_policy_deny  = list(string)
  }))
  default = []
}
