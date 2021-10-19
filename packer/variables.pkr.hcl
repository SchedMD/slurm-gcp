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

##########
# LOCALS #
##########

local "ssh_passwords" {
  expression = var.builds.*.ssh_password
  sensitive  = true
}

###########
# GENERAL #
###########

variable "project" {
  type = string
}

variable "zone" {
  type = string
}

#########
# IMAGE #
#########

variable "source_image_project_id" {
  description = "A list of project IDs to search for the source image. Packer will search the first project ID in the list first, and fall back to the next in the list, until it finds the source image."
  type        = list(string)
  default     = []
}

variable "skip_create_image" {
  type    = bool
  default = false
}

###########
# NETWORK #
###########

variable "network_project_id" {
  description = "The project ID for the network and subnetwork to use for launched instance."
  type        = string
  default     = null
}

variable "subnetwork" {
  description = "The subnetwork ID or URI to use for the launched instance."
  type        = string
  default     = null
}

variable "tags" {
  description = "Assign network tags to apply firewall rules to VM instance."
  type        = list(string)
  default     = null
}

#############
# PROVISION #
#############

variable "slurm_version" {
  description = "Slurm version (e.g. 20.11.8, 20.11-latest) or branch (e.g. b:slurm-20-11-8-1)."
  type        = string
  default     = "20.11.8"
  validation {
    condition     = can(regex("^\\d{2}\\.\\d{2}(\\.\\d+|-latest)$|^b:.+$", var.slurm_version))
    error_message = "Slurm version must pass '^\\d{2}\\.\\d{2}(\\.\\d+|-latest)$|^b:.+$'."
  }
}

##########
# BUILDS #
##########

variable "service_account_email" {
  description = "The service account email to use. If 'null' or 'default', then the default email will be used."
  type        = string
  default     = null
}

variable "service_account_scopes" {
  description = "Service account scopes to attach to the instance. See https://cloud.google.com/compute/docs/access/service-accounts."
  type        = list(string)
  default     = null
}

variable "builds" {
  type = list(object({
    ### image ###
    source_image        = string       // description: Source disk image.
    source_image_family = string       // description: Source image family.
    image_licenses      = list(string) // description: Licenses to apply to the created image.
    labels              = map(string)  // description: Key/value pair labels to apply to the launched instance and image.

    ### ssh ###
    ssh_username = string // description: The username to connect to SSH with. Default: "packer"
    ssh_password = string // description: A plaintext password to use to authenticate with SSH. (sensitive)

    ### instance ###
    machine_type = string // description: Machine type to create (e.g. n1-standard-1).
    preemptible  = bool   // description: If true, launch a preemptible instance.

    ### root of trust ###
    enable_secure_boot          = bool // description: Create a Shielded VM image with Secure Boot enabled. See https://cloud.google.com/security/shielded-cloud/shielded-vm#secure-boot.
    enable_vtpm                 = bool // description: Create a Shielded VM image with virtual trusted platform module Measured Boot enabled. See https://cloud.google.com/security/shielded-cloud/shielded-vm#vtpm.
    enable_integrity_monitoring = bool // description: Integrity monitoring helps you understand and make decisions about the state of your VM instances. Note: integrity monitoring relies on having vTPM enabled. See https://cloud.google.com/security/shielded-cloud/shielded-vm#integrity-monitoring.

    ### storage ###
    disk_size = number // description: The size of the disk in GB. This defaults to 10, which is 10GB.
    disk_type = string // description: Type of disk used to back your instance, like pd-ssd or pd-standard. Defaults to pd-standard.
  }))
}
