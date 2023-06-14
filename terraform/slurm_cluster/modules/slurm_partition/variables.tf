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

variable "partition_name" {
  description = "Name of Slurm partition."
  type        = string

  validation {
    condition     = can(regex("^[a-z](?:[a-z0-9]{0,6})$", var.partition_name))
    error_message = "Variable 'partition_name' must be a match of regex '^[a-z](?:[a-z0-9]{0,6})$'."
  }
}

variable "partition_conf" {
  description = <<EOD
Slurm partition configuration as a map.
See https://slurm.schedmd.com/slurm.conf.html#SECTION_PARTITION-CONFIGURATION
EOD
  type        = map(string)
  default     = {}
}

variable "partition_startup_scripts" {
  description = "List of scripts to be ran on compute VM startup."
  type = list(object({
    filename = string
    content  = string
  }))
  default = []
}

variable "partition_startup_scripts_timeout" {
  description = <<EOD
The timeout (seconds) applied to each script in partition_startup_scripts. If
any script exceeds this timeout, then the instance setup process is considered
failed and handled accordingly.

NOTE: When set to 0, the timeout is considered infinite and thus disabled.
EOD
  type        = number
  default     = 300
}

variable "partition_nodeset" {
  description = "Slurm nodesets by name, as a list of string."
  type        = set(string)
  default     = []
}

variable "partition_nodeset_dyn" {
  description = "Slurm nodesets (dynamic) by name, as a list of string."
  type        = set(string)
  default     = []
}

variable "enable_job_exclusive" {
  description = <<EOD
Enables job exclusivity. A job will run exclusively on the scheduled nodes.
EOD
  type        = bool
  default     = false
}

variable "enable_placement_groups" {
  description = <<EOD
Enables job placement groups. Instances will be colocated for a job.
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
