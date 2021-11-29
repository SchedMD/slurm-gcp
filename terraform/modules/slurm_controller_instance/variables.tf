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

variable "zone" {
  type        = string
  description = "Zone where the instances should be created. If not specified, instances will be spread across available zones in the region."
  default     = null
}

variable "metadata_controller" {
  type        = map(string)
  description = "Metadata key/value pairs to make available from within the controller instances."
  default     = null
}

variable "metadata_compute" {
  type        = map(string)
  description = "Metadata key/value pairs to make available from within the compute instances."
  default     = null
}

#########
# SLURM #
#########

variable "cluster_name" {
  type        = string
  description = "Cluster name, used resource naming and slurm accounting."
  default     = null

  validation {
    condition = (
      can(regex("(^[a-z][-a-z0-9]{0,15}$)", var.cluster_name))
      || var.cluster_name == null
    )
    error_message = "Must be a match of regex '(^[a-z][-a-z0-9]{0,15}$)'."
  }
}

variable "slurm_cluster_id" {
  type        = string
  description = "The Cluster ID to use. If 'null', then an ID will be generated."
  default     = null
}

variable "enable_devel" {
  type        = bool
  description = "Enables development mode. Not for production use."
  default     = false
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

variable "jwt_key" {
  type        = string
  description = "Cluster jwt authentication key. If 'null', then a key will be generated instead."
  default     = null
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
  description = "Use this database instead of the one on the controller."
  type = object({
    server_ip = string # description: Address of the database server.
    user      = string # description: The user to access the database as.
    password  = string # description: The password, given the user, to access the given database. (sensitive)
    db_name   = string # description: The database to access.
  })
  default   = null
  sensitive = true
}

variable "controller_d" {
  type        = string
  description = "Path to directory containing user controller provisioning scripts."
  default     = null
}

variable "compute_d" {
  type        = string
  description = "Path to directory containing user compute provisioning scripts."
  default     = null
}

variable "network_storage" {
  description = "Storage to mounted on all instances"
  type = list(object({
    server_ip     = string # description: Address of the storage server.
    remote_mount  = string # description: The location in the remote instance filesystem to mount from.
    local_mount   = string # description: The location on the instance filesystem to mount to.
    fs_type       = string # description: Filesystem type (e.g. "nfs").
    mount_options = string # description: Options to mount with.
  }))
  default = []
}

variable "login_network_storage" {
  description = "Storage to mounted on login and controller instances"
  type = list(object({
    server_ip     = string # description: Address of the storage server.
    remote_mount  = string # description: The location in the remote instance filesystem to mount from.
    local_mount   = string # description: The location on the instance filesystem to mount to.
    fs_type       = string # description: Filesystem type (e.g. "nfs").
    mount_options = string # description: Options to mount with.
  }))
  default = []
}

variable "template_map" {
  type        = map(string)
  description = "Slurm compute templates as a map. Key=slurm_template_name Value=template_self_link"
  default     = {}

  validation {
    condition = alltrue([
      for t, l in var.template_map : can(regex("(^[a-z][-a-z0-9]*$)", t))
    ])
    error_message = "Keys must be a match of regex '(^[a-z][-a-z0-9]*$)'."
  }
}

variable "partitions" {
  description = "Cluster partitions as a map."
  type = map(object({
    subnetwork  = string      # description: The subnetwork name to create instances in.
    region      = string      # description: The subnetwork region to create instances in.
    zone_policy = map(string) # description: Zone location policy for regional bulkInsert.
    nodes = list(object({
      template      = string # description: Slurm template key from variable 'compute_template'.
      count_static  = number # description: Number of static nodes. These nodes are exempt from SuspendProgram.
      count_dynamic = number # description: Number of dynamic nodes. These nodes are subject to SuspendProgram and ResumeProgram.
    }))
    network_storage = list(object({
      server_ip     = string # description: Address of the storage server.
      remote_mount  = string # description: The location in the remote instance filesystem to mount from.
      local_mount   = string # description: The location on the instance filesystem to mount to.
      fs_type       = string # description: Filesystem type (e.g. "nfs").
      mount_options = string # description: Options to mount with.
    }))
    exclusive        = bool        # description: Enables job exclusivity.
    placement_groups = bool        # description: Enables partition placement groups.
    conf             = map(string) # description: Slurm partition configurations as a map.
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.partitions : can(regex("(^[a-z][a-z0-9]*$)", k))
    ])
    error_message = "Keys must be a match of regex '(^[a-z][a-z0-9]*$)'."
  }
}

variable "cloud_parameters" {
  description = "cloud.conf key/value as a map."
  type        = map(string)
  default     = {}
}
