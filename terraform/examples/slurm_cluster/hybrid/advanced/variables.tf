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

############
# FIREWALL #
############

variable "firewall_network_name" {
  type        = string
  description = "Name of the network this set of firewall rules applies to."
  default     = "default"
}

#################
# CONFIGURATION #
#################

variable "cloud_parameters" {
  description = "cloud.conf key/value as a map."
  type        = map(string)
  default     = {}
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

variable "compute_d" {
  description = "Path to directory containing user compute provisioning scripts."
  type        = string
  default     = null
}

##############
# CONTROLLER #
##############

variable "controller_hybrid_config" {
  description = <<EOD
Creates a hybrid controller with given configuration.
See 'main.tf' for valid keys.
EOD
  type        = map(any)
  default     = {}
}

###########
# COMPUTE #
###########

variable "compute_node_groups_defaults" {
  description = "Defaults for compute_node_groups in partitions."
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
