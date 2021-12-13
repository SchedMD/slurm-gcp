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
  description = "Project ID."
  type        = string
}

############
# METADATA #
############

variable "metadata_compute" {
  description = "Metadata key/value pairs to make available from within the compute instances."
  type        = map(string)
  default     = {}
}

#########
# SLURM #
#########

variable "cluster_name" {
  description = "Cluster name, used for resource naming."
  type        = string
}

variable "compute_d" {
  description = "Path to directory containing user compute provisioning scripts."
  type        = string
  default     = null
}

variable "enable_devel" {
  description = "Enables development mode. Not for production use."
  type        = bool
  default     = false
}
