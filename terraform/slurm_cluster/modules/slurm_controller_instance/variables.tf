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

variable "project_id" {
  type        = string
  description = "Project ID to create resources in."
}

###########
# NETWORK #
###########

variable "network" {
  type        = string
  description = "Network to deploy to. Only one of network or subnetwork should be specified."
  default     = ""
}

variable "subnetwork" {
  type        = string
  description = "Subnet to deploy to. Only one of network or subnetwork should be specified."
  default     = ""
}

variable "subnetwork_project" {
  type        = string
  description = "The project that subnetwork belongs to."
  default     = ""
}

variable "region" {
  type        = string
  description = "Region where the instances should be created."
  default     = null
}

############
# INSTANCE #
############

variable "instance_template" {
  type        = string
  description = "Instance template self_link used to create compute instances."
}

variable "static_ips" {
  type        = list(string)
  description = "List of static IPs for VM instances."
  default     = []
}

variable "access_config" {
  description = "Access configurations, i.e. IPs via which the VM instance can be accessed via the Internet."
  type = list(object({
    nat_ip       = string
    network_tier = string
  }))
  default = []
}

variable "zone" {
  type        = string
  description = <<EOD
Zone where the instances should be created. If not specified, instances will be
spread across available zones in the region.
EOD
  default     = null
}

variable "metadata" {
  type        = map(string)
  description = "Metadata, provided as a map"
  default     = {}
}

#########
# SLURM #
#########

variable "slurm_cluster_name" {
  type        = string
  description = "The cluster name, used for resource naming and slurm accounting."

  validation {
    condition     = can(regex("^[a-z](?:[a-z0-9]{0,9})$", var.slurm_cluster_name))
    error_message = "Variable 'slurm_cluster_name' must be a match of regex '^[a-z](?:[a-z0-9]{0,9})$'."
  }
}

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

variable "slurmdbd_conf_tpl" {
  type        = string
  description = "Slurm slurmdbd.conf template file path."
  default     = null
}

variable "slurm_conf_tpl" {
  type        = string
  description = "Slurm slurm.conf template file path."
  default     = null
}

variable "cgroup_conf_tpl" {
  type        = string
  description = "Slurm cgroup.conf template file path."
  default     = null
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

variable "partitions" {
  description = "Cluster partitions as a list."
  type = list(object({
    compute_list = list(string)
    partition = object({
      enable_job_exclusive    = bool
      enable_placement_groups = bool
      network_storage = list(object({
        server_ip     = string
        remote_mount  = string
        local_mount   = string
        fs_type       = string
        mount_options = string
      }))
      partition_conf = map(string)
      partition_name = string
      partition_nodes = map(object({
        bandwidth_tier         = string
        node_count_dynamic_max = number
        node_count_static      = number
        enable_spot_vm         = bool
        group_name             = string
        instance_template      = string
        node_conf              = map(string)
        spot_instance_config = object({
          termination_action = string
        })
      }))
      subnetwork        = string
      zone_policy_allow = list(string)
      zone_policy_deny  = list(string)
    })
  }))
  default = []

  validation {
    condition = alltrue([
      for x in var.partitions[*].partition : can(regex("^[a-z](?:[a-z0-9]*)$", x.partition_name))
    ])
    error_message = "Items 'partition_name' must be a match of regex '^[a-z](?:[a-z0-9]*)$'."
  }
}

variable "cloud_parameters" {
  description = "cloud.conf options."
  type = object({
    resume_rate     = number
    resume_timeout  = number
    suspend_rate    = number
    suspend_timeout = number
  })
  default = {
    resume_rate     = 0
    resume_timeout  = 300
    suspend_rate    = 0
    suspend_timeout = 300
  }
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
