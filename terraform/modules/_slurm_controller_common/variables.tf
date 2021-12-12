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
  description = "Project ID."
}

############
# METADATA #
############

variable "metadata_compute" {
  type        = map(string)
  description = "Metadata key/value pairs to make available from within the compute instances."
  default     = null
}

#########
# SLURM #
#########

variable "cluster_name" {
  type        = string
  description = "Cluster name, used for resource naming and slurm accounting."
}

variable "slurm_cluster_id" {
  type        = string
  description = "The Cluster ID."
}

variable "enable_devel" {
  type        = bool
  description = "Enables development mode. Not for production use."
  default     = false
}

variable "munge_key" {
  type        = string
  description = "Cluster munge authentication key. If 'null', then a key will be generated instead."
  default     = null
  sensitive   = true

  validation {
    condition = (
      var.munge_key == null
      ? true
      : length(var.munge_key) >= 32 && length(var.munge_key) <= 1024
    )
    error_message = "Munge key must be between 32 and 1024 bytes."
  }
}

variable "jwt_key" {
  type        = string
  description = "Cluster jwt authentication key. If 'null', then a key will be generated instead."
  default     = null
  sensitive   = true
}

variable "compute_d" {
  type        = string
  description = "Path to directory containing user compute provisioning scripts."
  default     = null
}
