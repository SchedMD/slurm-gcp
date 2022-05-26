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

variable "slurm_cluster_name" {
  description = "Cluster name, for resource filtering."
  type        = string

  validation {
    condition     = can(regex("^[a-z](?:[a-z0-9]{0,9})$", var.slurm_cluster_name))
    error_message = "Variable 'slurm_cluster_name' must be a match of regex '^[a-z](?:[a-z0-9]{0,9})$'."
  }
}

variable "partition_name" {
  description = "Partition name."
  type        = string
  default     = ""

  validation {
    condition     = length(var.partition_name) > 0 ? can(regex("^[a-z](?:[a-z0-9]*)$", var.partition_name)) : true
    error_message = "Variable 'partition_name' must be a match of regex '^[a-z](?:[a-z0-9]*)$'."
  }
}

variable "triggers" {
  description = "Additional Terraform triggers."
  type        = map(string)
  default     = {}
}

variable "when_destroy" {
  description = "Run only on `terraform destroy`?"
  type        = bool
  default     = false
}
