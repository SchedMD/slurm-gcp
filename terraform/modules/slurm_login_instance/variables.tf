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

variable "num_instances" {
  type        = number
  description = "Number of instances to create. This value is ignored if static_ips is provided."
  default     = 1
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
  description = "Metadata key/value pairs to make available from within the instances."
  default     = null
}

#########
# SLURM #
#########

variable "cluster_name" {
  type        = string
  description = "Cluster name, used resource naming and slurm accounting."

  validation {
    condition = (
      can(regex("(^[a-z][a-z0-9]{0,7}$)", var.cluster_name))
      || var.cluster_name == null
    )
    error_message = "Must be a match of regex '(^[a-z][a-z0-9]{0,7}$)'."
  }
}

variable "slurm_cluster_id" {
  type        = string
  description = "The Cluster ID, used to label resources."
}

variable "munge_key" {
  type        = string
  description = "Cluster munge authentication key. If 'null', then a key will be generated instead."
  default     = null

  validation {
    condition = (
      var.munge_key == null
      ? true
      : length(var.munge_key) >= 32 && length(var.munge_key) <= 1024
    )
    error_message = "Munge key must be between 32 and 1024 bytes."
  }
}

variable "serf_keys" {
  type        = list(string)
  description = "Cluster serf agent keys. If 'null' or '[]', then keys will be generated instead."
  default     = null

  validation {
    condition = (
      var.serf_keys == null
      ? true
      : alltrue([
        for key in var.serf_keys
        : length(key) == 16 || length(key) == 24 || length(key) == 32
      ])
    )
    error_message = "Serf keys must be either 16, 24, or 32 bytes."
  }
}

variable "network_storage" {
  description = <<EOD
Storage to mounted on all instances.
* server_ip     : Address of the storage server.
* remote_mount  : The location in the remote instance filesystem to mount from.
* local_mount   : The location on the instance filesystem to mount to.
* fs_type       : Filesystem type (e.g. "nfs").
* mount_options : Raw options to pass to 'mount'.
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
Storage to mounted on login and controller instances.
* server_ip     : Address of the storage server.
* remote_mount  : The location in the remote instance filesystem to mount from.
* local_mount   : The location on the instance filesystem to mount to.
* fs_type       : Filesystem type (e.g. "nfs").
* mount_options : Raw options to pass to 'mount'.
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
