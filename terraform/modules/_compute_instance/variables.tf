/**
 * Copyright 2021 SchedMD LLC
 * Modified for use with the Slurm Resource Manager.
 * 
 * Copyright 2018 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
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
  description = "The project that subnetwork belongs to"
  default     = ""
}

############
# INSTANCE #
############

variable "hostname" {
  type        = string
  description = "Hostname of instances"
  default     = ""
}

variable "add_hostname_suffix" {
  type        = bool
  description = "Adds a suffix to the hostname"
  default     = true
}

variable "static_ips" {
  type        = list(string)
  description = "List of static IPs for VM instances"
  default     = []
}

variable "access_config" {
  type = list(object({
    nat_ip       = string
    network_tier = string
  }))
  description = "Access configurations, i.e. IPs via which the VM instance can be accessed via the Internet."
  default     = []
}

variable "num_instances" {
  type        = number
  description = "Number of instances to create. This value is ignored if static_ips is provided."
  default     = 1
}

variable "instance_template" {
  type        = string
  description = "Instance template self_link used to create compute instances"
}

variable "region" {
  type        = string
  description = "Region where the instances should be created."
  default     = null
}

variable "zone" {
  type        = string
  description = "Zone where the instances should be created. If not specified, instances will be spread across available zones in the region."
  default     = null
}

############
# OVERRIDE #
############

variable "metadata_startup_script" {
  type        = string
  description = "An alternative to using the startup-script metadata key, except this one forces the instance to be recreated (thus re-running the script) if it is changed. This replaces the startup-script metadata key on the created instance and thus the two mechanisms are not allowed to be used simultaneously. Users are free to use either mechanism - the only distinction is that this separate attribute will cause a recreate on modification."
  default     = null
}

variable "metadata" {
  type        = map(string)
  description = "Metadata key/value pairs to make available from within the instances."
  default     = null
}
