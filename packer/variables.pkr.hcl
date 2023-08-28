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

###########
# GENERAL #
###########

variable "project_id" {
  type = string
}

variable "zone" {
  type = string
}

variable "slurmgcp_version" {
  description = "slurm-gcp version used in the image family name."
  type        = string
  default     = "next"
}

variable "image_family_alt" {
  description = "When set, use in the generated image family in place of the source family."
  type        = string
  default     = null
}

variable "image_family_name" {
  description = "When set, use for the image family instead of the auto-generated name."
  type        = string
  default     = null
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
  description = <<-EOD
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
  default     = "23.02.4"

  validation {
    condition     = can(regex("^(?P<major>\\d{2})\\.(?P<minor>\\d{2})(?P<end>\\.(?P<patch>\\d+)(?P<sub>-(?P<rev>\\d+\\w*))?|\\-(?P<meta>latest))$|^b:(?P<branch>.+)$", var.slurm_version))
    error_message = "Slurm version must pass '^(?P<major>\\d{2})\\.(?P<minor>\\d{2})(?P<end>\\.(?P<patch>\\d+)(?P<sub>-(?P<rev>\\d+\\w*))?|\\-(?P<meta>latest))$|^b:(?P<branch>.+)$'."
  }
}

variable "prefix" {
  description = "Prefix for image and instance."
  type        = string
  default     = null

  validation {
    condition     = var.prefix == null || can(regex("^[a-z](?:[a-z0-9]*)$", var.prefix))
    error_message = "Variable 'prefix' must pass '^[a-z](?:[a-z0-9]*)$'."
  }
}

variable "variant" {
  description = "variant suffix to distinguish between variants on the same base image"
  type        = string
  default     = null

  validation {
    condition     = var.variant == null || can(regex("^[a-z](?:[a-z0-9]*)$", var.variant))
    error_message = "Variable 'variant' must pass '^[a-z](?:[a-z0-9]*)$'."
  }
}

variable "install_cuda" {
  description = "enable install of cuda and nvidia driver"
  type        = bool
  default     = true
}

variable "nvidia_version" {
  description = "choose the major nvidia version to install via runfile. Must match a version file in ansible cuda role."
  type        = string
  default     = "latest"
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

######################
# BUILD VM VARIABLES #
######################

variable "source_image_project_id" {
  description = "project id of the source image."
  type        = string
}

variable "source_image" {
  description = "Source disk image."
  type        = string
  default     = null
}

variable "source_image_family" {
  description = "Source image family."
  type        = string
  default     = null
}

variable "service_account_email" {
  description = "The service account email to use. If 'null' or 'default', then the default email will be used."
  type        = string
  default     = "default"
}

variable "service_account_scopes" {
  description = <<-EOD
Service account scopes to attach to the instance. See
https://cloud.google.com/compute/docs/access/service-accounts.
EOD
  type        = list(string)
  default = [
    "https://www.googleapis.com/auth/cloud-platform",
  ]
}

variable "image_licenses" {
  description = "Licenses to apply to the created image."
  type        = list(string)
  default     = null
}

variable "labels" {
  description = "Key/value pair labels to apply to the launched instance and image."
  type        = map(string)
  default     = {}
}

variable "ssh_username" {
  description = "The username to connect to SSH with."
  type        = string
  default     = "packer"
}

variable "ssh_password" {
  description = "A plaintext password to use to authenticate with SSH."
  type        = string
  sensitive   = true
  default     = null
}

variable "machine_type" {
  description = "Machine type to create (e.g. n1-standard-1)."
  type        = string
  default     = "n1-standard-16"
}

variable "preemptible" {
  description = "If true, launch a preemptible instance."
  type        = bool
  default     = false
}

variable "enable_secure_boot" {
  description = <<-EOD
    Create a Shielded VM image with Secure Boot enabled. See
    https://cloud.google.com/security/shielded-cloud/shielded-vm#secure-boot."
    EOD
  type        = bool
  default     = false
}

variable "enable_vtpm" {
  description = <<-EOD
    Create a Shielded VM image with virtual trusted platform module
    Measured Boot enabled. See
    https://cloud.google.com/security/shielded-cloud/shielded-vm#vtpm.
    EOD
  type        = bool
  default     = false
}

variable "enable_integrity_monitoring" {
  description = <<-EOD
    Integrity monitoring helps you understand and make decisions about the state of
    your VM instances. Note: integrity monitoring relies on having vTPM enabled. See
    https://cloud.google.com/security/shielded-cloud/shielded-vm#integrity-monitoring.
    EOD
  type        = bool
  default     = false
}

variable "disk_size" {
  description = "The size of the disk in GB. This defaults to 10 in GCP, which is 10GB."
  type        = number
  default     = 32
}

variable "disk_type" {
  description = "Type of disk used to back your instance, like pd-ssd or pd-standard."
  type        = string
  default     = "pd-standard"
}

variable "on_host_maintenance" {
  type    = string
  default = "TERMINATE"
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
