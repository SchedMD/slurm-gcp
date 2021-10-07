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

###########
# NETWORK #
###########

variable "subnetwork_project" {
  type        = string
  description = "The ID of the project in which the subnetwork belongs. If it is not provided, the provider project is used."
  default     = null
}

variable "network" {
  type        = string
  description = "The name or self_link of the network to attach this interface to. Use network attribute for Legacy or Auto subnetted networks and subnetwork for custom subnetted networks."
  default     = null
}

variable "subnetwork" {
  type        = string
  description = "The name of the subnetwork to attach this interface to. The subnetwork must exist in the same region this instance will be created in. Either network or subnetwork must be provided."
  default     = null
}

variable "region" {
  type        = string
  description = "Region where the instance template should be created."
  default     = null
}

variable "tags" {
  type        = list(string)
  description = "Network tag list."
  default     = null
}

############
# TEMPLATE #
############

variable "instance_template_project" {
  type        = string
  description = "Project where the instance template comes from. If it is not provided, the provider project is used."
  default     = null
}

variable "instance_template" {
  type        = string
  description = "Instance template REGEX. Takes priority over manual configurations when not null."
  default     = null
}

variable "name_prefix" {
  type        = string
  description = "Prefix for template resource."
  default     = "instance-template"
}

############
# INSTANCE #
############

variable "machine_type" {
  type        = string
  description = "Machine type to create."
}

variable "min_cpu_platform" {
  type        = string
  description = "Specifies a minimum CPU platform. Applicable values are the friendly names of CPU platforms, such as Intel Haswell or Intel Skylake. See the complete list: https://cloud.google.com/compute/docs/instances/specify-min-cpu-platform"
  default     = null
}

variable "gpu" {
  type = object({
    type  = string
    count = number
  })
  description = "GPU information. Type and count of GPU to attach to the instance template. See https://cloud.google.com/compute/docs/gpus more details"
  default     = null
}

variable "service_account" {
  type = object({
    email  = string
    scopes = set(string)
  })
  description = "Service account to attach to the instances."
  default     = null
}

variable "shielded_instance_config" {
  type = object({
    enable_secure_boot          = bool
    enable_vtpm                 = bool
    enable_integrity_monitoring = bool
  })
  description = "Shielded VM configuration for the instance. Note: not used unless enable_shielded_vm is 'true'"
  default = {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
    enable_vtpm                 = true
  }
}

variable "enable_confidential_vm" {
  type        = bool
  description = "Enable the Confidential VM configuration. Note: the instance image must support option."
  default     = false
}

variable "enable_shielded_vm" {
  type        = bool
  description = "Enable the Shielded VM configuration. Note: the instance image must support option."
  default     = false
}

variable "disable_smt" {
  type        = bool
  description = "Disable CPU Simultaneous Multi-Threading (SMT): Intel Hyper-Threading (HT)."
  default     = false
}

variable "preemptible" {
  type        = bool
  description = "Allow the instance to be preempted."
  default     = false
}

############
# METADATA #
############

variable "metadata" {
  type        = map(string)
  description = "Metadata, provided as a map"
  default     = null
}

################
# SOURCE IMAGE #
################

variable "source_image_project" {
  type        = string
  description = "Project where the source image comes from. If it is not provided, the provider project is used."
  default     = null
}

variable "source_image_family" {
  type        = string
  description = "Source image family. If neither source_image nor source_image_family is specified, defaults to the latest public CentOS image."
  default     = null
}

variable "source_image" {
  type        = string
  description = "Source disk image. If neither source_image nor source_image_family is specified, defaults to the latest public CentOS image."
  default     = null
}

########
# DISK #
########

variable "disk_type" {
  type        = string
  description = "Boot disk type, can be either pd-ssd, local-ssd, or pd-standard."
  default     = "pd-standard"
}

variable "disk_size_gb" {
  type        = number
  description = "Boot disk size in GB."
  default     = 100
}

variable "disk_labels" {
  type        = map(string)
  description = "Labels to be assigned to boot disk, provided as a map."
  default     = null
}

variable "disk_auto_delete" {
  type        = bool
  description = "Whether or not the boot disk should be auto-deleted."
  default     = true
}

variable "additional_disks" {
  type = list(object({
    disk_name    = string
    device_name  = string
    disk_type    = string
    disk_size_gb = number
    disk_labels  = map(string)
    auto_delete  = bool
    boot         = bool
  }))
  description = "List of maps of disks."
  default     = null
}
