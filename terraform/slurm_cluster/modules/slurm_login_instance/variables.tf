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
  description = "The GCP project ID"
  default     = null
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

variable "enable_public_ip" {
  description = "Enables IP address to access the Internet."
  type        = bool
  default     = false
}

variable "network_tier" {
  type        = string
  description = <<-EOD
    The networking tier used for configuring this instance. This field can take the following values: PREMIUM, FIXED_STANDARD or STANDARD.
    Ignored if enable_public_ip is false.
  EOD
  default     = "STANDARD"

  validation {
    condition     = var.network_tier == null ? true : contains(["PREMIUM", "FIXED_STANDARD", "STANDARD"], var.network_tier)
    error_message = "Allow values are: 'PREMIUM', 'FIXED_STANDARD', 'STANDARD'."
  }
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

#########
# SLURM #
#########

variable "slurm_cluster_name" {
  type        = string
  description = "Cluster name, used for resource naming."

  validation {
    condition     = can(regex("^[a-z](?:[a-z0-9]{0,9})$", var.slurm_cluster_name))
    error_message = "Variable 'slurm_cluster_name' must be a match of regex '^[a-z](?:[a-z0-9]{0,9})$'."
  }
}

variable "suffix" {
  description = "Login name suffix."
  type        = string
  default     = "frontend"
}
