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
  default     = "advanced"
}

variable "enable_devel" {
  type        = bool
  description = "Enables development process for faster iterations. NOTE: *NOT* intended for production use."
  default     = false
}

variable "region" {
  type        = string
  description = "The default region to place resources in."
}

#################
# CONFIGURATION #
#################

variable "cloud_parameters" {
  description = "cloud.conf key/value as a map."
  type        = map(string)
  default     = {}
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

variable "munge_key" {
  description = "Cluster munge authentication key. If 'null', then a key will be generated instead."
  type        = string
  default     = ""
  sensitive   = true
}

variable "jwt_key" {
  description = "Cluster jwt authentication key. If 'null', then a key will be generated instead."
  type        = string
  default     = ""
  sensitive   = true
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

variable "controller_d" {
  description = "List of scripts to be ran on controller VM startup."
  type = list(object({
    filename = string
    content  = string
  }))
  default = []
}

variable "compute_d" {
  description = "List of scripts to be ran on compute VM startup."
  type = list(object({
    filename = string
    content  = string
  }))
  default = []
}

############
# DEFAULTS #
############

variable "slurm_cluster_defaults" {
  description = <<EOD
Defaults for cluster controller, login, and compute nodes.

Controller node default value priority order:
- controller_instance_config
- slurm_cluster_defaults

Login node default value priority order:
- login_node_groups
- login_node_groups_defaults
- slurm_cluster_defaults

Compute node default value priority order:
- compute_node_groups
- compute_node_groups_defaults
- slurm_cluster_defaults
EOD
  type        = any
  default     = {}
}

##############
# CONTROLLER #
##############

variable "controller_instance_config" {
  description = <<EOD
Creates a controller instance with given configuration.

Default value priority order:
- controller_instance_config
- slurm_cluster_defaults
EOD
  type        = any
  default     = {}
}

###################
# LOGIN: DEFAULTS #
###################

variable "login_node_groups_defaults" {
  description = <<EOD
Defaults for login_node_groups.

Default value priority order:
- login_node_groups
- login_node_groups_defaults
- slurm_cluster_defaults
EOD
  type        = any
  default     = {}
}

#################
# LOGIN: GROUPS #
#################

variable "login_node_groups" {
  description = "List of slurm login instance definitions."
  type        = list(any)
  default     = []
}

#####################
# COMPUTE: DEFAULTS #
#####################

variable "compute_node_groups_defaults" {
  description = <<EOD
Defaults for compute_node_groups in partitions.

Default value priority order:
- compute_node_groups
- compute_node_groups_defaults
- slurm_cluster_defaults
EOD
  type        = any
  default     = {}
}

##############
# PARTITIONS #
##############

variable "partitions" {
  description = "Cluster partition configuration as a list."
  type        = list(any)
  default     = []
}
