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
    condition     = can(regex("^[a-z](?:[a-z0-9]*)$", var.partition_name))
    error_message = "Variable 'partition_name' must be a match of regex '^[a-z](?:[a-z0-9]*)$'."
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

variable "partition_nodeset_tpu" {
  description = "Slurm nodesets (tpu) by name, as a list of string."
  type        = set(string)
  default     = []
}

variable "default" {
  description = <<-EOD
    If this is true, jobs submitted without a partition specification will utilize this partition.
    This sets 'Default' in partition_conf.
    See https://slurm.schedmd.com/slurm.conf.html#OPT_Default for details.
  EOD
  type        = bool
  default     = false
}

variable "resume_timeout" {
  description = <<-EOD
    Maximum time permitted (in seconds) between when a node resume request is issued and when the node is actually available for use.
    If null is given, then a smart default will be chosen depending on nodesets in partition.
    This sets 'ResumeTimeout' in partition_conf.
    See https://slurm.schedmd.com/slurm.conf.html#OPT_ResumeTimeout_1 for details.
  EOD
  type        = number
  default     = 300

  validation {
    condition     = var.resume_timeout == null ? true : var.resume_timeout > 0
    error_message = "Value must be > 0."
  }
}

variable "suspend_time" {
  description = <<-EOD
    Nodes which remain idle or down for this number of seconds will be placed into power save mode by SuspendProgram.
    This sets 'SuspendTime' in partition_conf.
    See https://slurm.schedmd.com/slurm.conf.html#OPT_SuspendTime_1 for details.
    NOTE: use value -1 to exclude partition from suspend.
  EOD
  type        = number
  default     = 300

  validation {
    condition     = var.suspend_time >= -1
    error_message = "Value must be >= -1."
  }
}

variable "suspend_timeout" {
  description = <<-EOD
    Maximum time permitted (in seconds) between when a node suspend request is issued and when the node is shutdown.
    If null is given, then a smart default will be chosen depending on nodesets in partition.
    This sets 'SuspendTimeout' in partition_conf.
    See https://slurm.schedmd.com/slurm.conf.html#OPT_SuspendTimeout_1 for details.
  EOD
  type        = number
  default     = null

  validation {
    condition     = var.suspend_timeout == null ? true : var.suspend_timeout > 0
    error_message = "Value must be > 0."
  }
}

variable "enable_job_exclusive" {
  description = <<EOD
Enables job exclusivity. A job will run exclusively on the scheduled nodes.
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
