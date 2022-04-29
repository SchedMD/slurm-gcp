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

variable "project_id" {
  type        = string
  description = "Project ID to create resources in."
}

variable "slurm_cluster_name" {
  type        = string
  description = "Cluster name, used for resource naming."
  default     = "winbind"
}

variable "region" {
  type        = string
  description = "The default region to place resources in."
}

variable "subnetwork" {
  type        = string
  description = "Subnet to deploy to. Only one of network or subnetwork should be specified."
  default     = "default"
}

variable "subnetwork_project" {
  type        = string
  description = "The project that subnetwork belongs to."
  default     = null
}

variable "smb_workgroup" {
  description = "SMB Workgroup"
  type        = string
}

variable "smb_realm" {
  description = "SMB Realm"
  type        = string
}

variable "smb_server" {
  description = "SMB Server"
  type        = string
}

variable "winbind_join" {
  description = "Username and password to authenticate the join with. (e.g. 'Administrator[%Password]')"
  type        = string
  sensitive   = true
}
