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

variable "nodeset_name" {
  description = "Name of Slurm nodeset."
  type        = string

  validation {
    condition     = can(regex("^[a-z](?:[a-z0-9]{0,14})$", var.nodeset_name))
    error_message = "Variable 'nodeset_name' must be a match of regex '^[a-z](?:[a-z0-9]{0,14})$'."
  }
}

variable "node_type" {
  description = "Specify a node type to base the vm configuration upon it."
  type        = string
  validation {
    condition     = contains(["v2-8", "v3-8"], var.node_type)
    error_message = "node_type \"${var.node_type}\" is not supported yet"
  }
}

variable "accelerator_config" {
  description = "Nodeset accelerator config, see https://cloud.google.com/tpu/docs/supported-tpu-configurations for details."
  type = object({
    topology = string
    version  = string
  })
  default = {
    topology = ""
    version  = ""
  }
  validation {
    condition     = var.accelerator_config.version == "" ? true : contains(["V2", "V3", "V4"], var.accelerator_config.version)
    error_message = "accelerator_config.version must be one of [\"V2\", \"V3\", \"V4\"]"
  }
  validation {
    condition     = var.accelerator_config.topology == "" ? true : can(regex("^[1-9]x[1-9](x[1-9])?$", var.accelerator_config.topology))
    error_message = "accelerator_config.topology must be a valid topology, like 2x2 4x4x4 4x2x4 etc..."
  }
}

variable "tf_version" {
  description = "Nodeset Tensorflow version, see https://cloud.google.com/tpu/docs/supported-tpu-configurations#tpu_vm for details."
  type        = string
}

variable "zone" {
  description = "Nodes will only be created in this zone. Check https://cloud.google.com/tpu/docs/regions-zones to get zones with TPU-vm in it."
  type        = string
}

variable "preemptible" {
  description = "Specify whether TPU-vms in this nodeset are preemtible, see https://cloud.google.com/tpu/docs/preemptible for details."
  type        = bool
}

variable "preserve_tpu" {
  description = "Specify whether TPU-vms will get preserve on suspend, if set to true, on suspend vm is stopped, on false it gets deleted"
  type        = bool
  default     = true
}

variable "project_id" {
  type        = string
  description = "Project ID to create resources in."
}

variable "node_count_static" {
  description = "Number of nodes to be statically created."
  type        = number
  default     = 0

  validation {
    condition     = var.node_count_static >= 0
    error_message = "Value must be >= 0."
  }
}

variable "node_count_dynamic_max" {
  description = "Maximum number of nodes allowed in this partition to be created dynamically."
  type        = number
  default     = 0

  validation {
    condition     = var.node_count_dynamic_max >= 0
    error_message = "Value must be >= 0."
  }
}

variable "enable_public_ip" {
  description = "Enables IP address to access the Internet."
  type        = bool
  default     = false
}

variable "data_disks" {
  type        = list(string)
  description = "The data disks to include in the TPU node"
  default     = []
}

##pending
#data disks
#accel config topology
#region zone or something
#cidr block for static IP
#more network config

##not for the moment
#shielded
#reservation

##to review

variable "service_account" {
  type = object({
    email  = string
    scopes = set(string)
  })
  description = <<EOD
Service account to attach to the TPU-vm. See
'main.tf:local.service_account' for the default.
EOD
  default     = null
}

# variable "subnetwork_self_link" {
#   description = "The subnetwork self_link to attach instances to."
#   type        = string

#   validation {
#     condition     = length(regexall("projects/([^/]*)", var.subnetwork_self_link)) > 0 && length(regexall("/regions/([^/]*)", var.subnetwork_self_link)) > 0
#     error_message = "Must be a self link."
#   }
#   default = null
# }

##previous

# variable "network_tier" {
#   type        = string
#   description = <<-EOD
#     The networking tier used for configuring this instance. This field can take the following values: PREMIUM, FIXED_STANDARD or STANDARD.
#     Ignored if enable_public_ip is false.
#   EOD
#   default     = "STANDARD"

#   validation {
#     condition     = var.network_tier == null ? true : contains(["PREMIUM", "FIXED_STANDARD", "STANDARD"], var.network_tier)
#     error_message = "Allow values are: 'PREMIUM', 'FIXED_STANDARD', 'STANDARD'."
#   }
# }

# variable "bandwidth_tier" {
#   description = <<-EOD
#     Tier 1 bandwidth increases the maximum egress bandwidth for VMs.
#     Using the `virtio_enabled` setting will only enable VirtioNet and will not enable TIER_1.
#     Using the `tier_1_enabled` setting will enable both gVNIC and TIER_1 higher bandwidth networking.
#     Using the `gvnic_enabled` setting will only enable gVNIC and will not enable TIER_1.
#     Note that TIER_1 only works with specific machine families & shapes and must be using an image that supports gVNIC. See [official docs](https://cloud.google.com/compute/docs/networking/configure-vm-with-high-bandwidth-configuration) for more details.
#   EOD
#   type        = string
#   default     = "platform_default"

#   validation {
#     condition     = contains(["platform_default", "virtio_enabled", "gvnic_enabled", "tier_1_enabled"], var.bandwidth_tier)
#     error_message = "Allowed values for bandwidth_tier are 'platform_default', 'virtio_enabled', 'gvnic_enabled', or 'tier_1_enabled'."
#   }
# }
