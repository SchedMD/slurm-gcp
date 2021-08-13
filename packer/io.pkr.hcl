# Copyright 2021 SchedMD LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

###########
# ACCOUNT #
###########

variable "project" {
  type = string
}

#########
# IMAGE #
#########

# One of the following:
# - source_image
# - source_image_family
# NOTE: 'source_image' takes precedence when both are provided.

variable "source_image" {
  type    = string
  default = null
}

variable "source_image_family" {
  type    = string
  default = null
}

variable "skip_create_image" {
  type    = bool
  default = null
}

variable "image_licenses" {
  type    = list(string)
  default = []
}

#######
# SSH #
#######

variable "ssh_username" {
  type    = string
  default = "packer"
}

variable "ssh_password" {
  type      = string
  default   = null
  sensitive = true
}

############
# INSTANCE #
############

variable "machine_type" {
  type    = string
  default = null
}

variable "preemptible" {
  type    = bool
  default = false
}

variable "zone" {
  type = string
}

### Root of Trust (RoT) ###

variable "enable_secure_boot" {
  type    = bool
  default = null
}

variable "enable_vtpm" {
  type    = bool
  default = null
}

variable "enable_integrity_monitoring" {
  type    = bool
  default = null
}

###########
# STORAGE #
###########

variable "disk_size" {
  type    = number
  default = null
}

variable "disk_type" {
  type    = string
  default = null
}

###########
# NETWORK #
###########

variable "network_project_id" {
  type    = string
  default = null
}

variable "subnetwork" {
  type    = string
  default = null
}

variable "tags" {
  type    = list(string)
  default = []
}

################
# PROVISIONING #
################

variable "slurm_version" {
  description = "Slurm version by git branch"
  type        = string
  default     = "slurm-20.11"
}
