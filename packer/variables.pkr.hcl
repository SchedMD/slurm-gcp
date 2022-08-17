# Copyright (C) SchedMD LLC.
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

variable "project_id" {
  type = string
}

variable "zone" {
  type = string
}

##################
# SSH CONNECTION #
##################

variable "use_iap" {
  description = "Use IAP proxy when connecting by SSH"
  type        = bool
  default     = false
}

variable "use_os_login" {
  description = "Use OS Login when connecting by SSH"
  type        = bool
  default     = false
}

#########
# IMAGE #
#########

variable "source_image_project_id" {
  description = <<EOD
A list of project IDs to search for the source image. Packer will search the
first project ID in the list first, and fall back to the next in the list,
until it finds the source image.
EOD
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
  description = <<EOD
The Slurm version to be installed via archive or 'git checkout'.

This value can be:
- archive stub (e.g. 21.08.8, 21.08.8-2, 21.08-latest)
  - See https://download.schedmd.com/slurm/
- git checkout [branch|tag|commit] (e.g. b:slurm-21.08, b:slurm-21-08-8-2)
  - branch
    - See https://github.com/SchedMD/slurm/branches
  - tag
    - See https://github.com/SchedMD/slurm/tags

> NOTE: Use prefix 'b:' to install via 'git checkout' instead of archive.
EOD
  type        = string
  default     = "22.05.3"

  validation {
    condition     = can(regex("^(?P<major>\\d{2})\\.(?P<minor>\\d{2})(?P<end>\\.(?P<patch>\\d+)(?P<sub>-(?P<rev>\\d+\\w*))?|\\-(?P<meta>latest))$|^b:(?P<branch>.+)$", var.slurm_version))
    error_message = "Slurm version must pass '^(?P<major>\\d{2})\\.(?P<minor>\\d{2})(?P<end>\\.(?P<patch>\\d+)(?P<sub>-(?P<rev>\\d+\\w*))?|\\-(?P<meta>latest))$|^b:(?P<branch>.+)$'."
  }
}

variable "prefix" {
  description = "Prefix for image and instance."
  type        = string
  default     = "schedmd"

  validation {
    condition     = can(regex("^[a-z](?:[a-z0-9]*)$", var.prefix))
    error_message = "Variable 'prefix' must pass '^[a-z](?:[a-z0-9]*)$'."
  }
}

variable "install_cuda" {
  description = "enable install of cuda and nvidia driver"
  type        = bool
  default     = true
}

variable "install_ompi" {
  description = "enable install of OpenMPI"
  type        = bool
  default     = true
}

variable "install_lustre" {
  description = "enable install of lustre fs client driver"
  type        = bool
  default     = true
}

variable "install_gcsfuse" {
  description = "enable install of GCS fuse driver"
  type        = bool
  default     = true
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
  description = <<EOD
Service account scopes to attach to the instance. See
https://cloud.google.com/compute/docs/access/service-accounts.
EOD
  type        = list(string)
  default     = null
}

variable "builds" {
  description = <<EOD
Set of build configurations.
* source_image : Source disk image.
* source_image_family : Source image family.
* image_licenses : Licenses to apply to the created image.
* labels : Key/value pair labels to apply to the launched instance and image.

* ssh_username : The username to connect to SSH with. Default: "packer"
* ssh_password : A plaintext password to use to authenticate with SSH. (sensitive)

* machine_type : Machine type to create (e.g. n1-standard-1).
* preemptible : If true, launch a preemptible instance.

* enable_secure_boot : Create a Shielded VM image with Secure Boot enabled. See
  https://cloud.google.com/security/shielded-cloud/shielded-vm#secure-boot.
* enable_vtpm : Create a Shielded VM image with virtual trusted platform module
  Measured Boot enabled. See
  https://cloud.google.com/security/shielded-cloud/shielded-vm#vtpm.
* enable_integrity_monitoring : Integrity monitoring helps you understand and
  make decisions about the state of your VM instances. Note: integrity
  monitoring relies on having vTPM enabled. See
  https://cloud.google.com/security/shielded-cloud/shielded-vm#integrity-monitoring.

* disk_size : The size of the disk in GB. This defaults to 10, which is 10GB.
* disk_type : Type of disk used to back your instance, like pd-ssd or
  pd-standard. Defaults to pd-standard.
EOD
  type = list(object({
    ### image ###
    source_image        = string
    source_image_family = string
    image_licenses      = list(string)
    labels              = map(string)

    ### ssh ###
    ssh_username = string
    ssh_password = string

    ### instance ###
    machine_type = string
    preemptible  = bool

    ### root of trust ###
    enable_secure_boot          = bool
    enable_vtpm                 = bool
    enable_integrity_monitoring = bool

    ### storage ###
    disk_size = number
    disk_type = string
  }))
}

###############################
# CUSTOM ANSIBLE PROVISIONERS #
###############################

variable "extra_ansible_provisioners" {
  description = "Extra ansible playbooks"
  type = list(object({
    playbook_file   = string
    galaxy_file     = string
    extra_arguments = list(string)
    user            = string
  }))
  default = []
}
