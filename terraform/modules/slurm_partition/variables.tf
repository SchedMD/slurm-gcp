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

variable "partition_name" {
  description = "Name of Slurm partition."
  type        = string
}

variable "partition_conf" {
  description = <<EOD
Slurm partition configuration as a map.
See https://slurm.schedmd.com/slurm.conf.html#SECTION_PARTITION-CONFIGURATION
EOD
  type        = map(string)
  default     = {}
}

variable "partition_nodes" {
  description = "Grouped nodes in the partition."
  type = list(object({
    node_group_name   = string
    instance_template = string
    count_static      = number
    count_dynamic     = number
  }))

  validation {
    condition     = length(var.partition_nodes) > 0
    error_message = "Partition must contain nodes."
  }

  validation {
    condition = alltrue([
      for x in var.partition_nodes : can(regex("(^[a-z][a-z0-9]*$)", x.node_group_name))
    ])
    error_message = "Items 'node_group_name' must be a match of regex '(^[a-z][a-z0-9]*$)'."
  }

  validation {
    condition = alltrue([
      for x in var.partition_nodes : x.count_static >= 0
    ])
    error_message = "Items 'count_static' must be >= 0."
  }

  validation {
    condition = alltrue([
      for x in var.partition_nodes : x.count_dynamic >= 0
    ])
    error_message = "Items 'count_dynamic' must be >= 0."
  }
}

variable "subnetwork_project" {
  description = "The project the subnetwork belongs to."
  type        = string
  default     = ""
}

variable "subnetwork" {
  description = "The subnetwork to attach instances to. A self_link is prefered."
  type        = string
}

variable "region" {
  description = "The region of the subnetwork."
  type        = string
  default     = ""
}

variable "zone_policy_allow" {
  description = <<EOD
Partition nodes will prefer to be created in the listed zones. If a zone appears
in both zone_policy_allow and zone_policy_deny, then zone_policy_deny will take
priority for that zone.
EOD
  type        = set(string)
  default     = []
}

variable "zone_policy_deny" {
  description = <<EOD
Partition nodes will not be created in the listed zones. If a zone appears in
both zone_policy_allow and zone_policy_deny, then zone_policy_deny will take
priority for that zone.
EOD
  type        = set(string)
  default     = []
}

variable "enable_job_exclusive" {
  description = <<EOD
Enables job exclusivity. A job will run exclusively on the scheduled nodes.
NOTE: enable_placement_groups=true will force enable_job_exclusive=true.
EOD
  type        = bool
  default     = false
}

variable "enable_placement_groups" {
  description = <<EOD
Enables job placement groups. Instances will be colocated for a job.
NOTE: enable_placement_groups=true will force enable_job_exclusive=true.
EOD
  type        = bool
  default     = false
}

variable "network_storage" {
  description = <<EOD
Storage to mounted on all instances in this partition.
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
