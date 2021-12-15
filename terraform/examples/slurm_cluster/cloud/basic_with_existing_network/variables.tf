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

variable "project_id" {
  type        = string
  description = "Project ID to create resources in."
}

variable "region" {
  type        = string
  description = "The region to place resources in."
}

variable "cluster_name" {
  type        = string
  description = "Cluster name, used for resource naming."
  default     = "basic"
}

variable "subnetwork_project" {
  description = "The project the subnetwork belongs to."
  type        = string
  default     = null
}

variable "subnetwork" {
  description = <<EOD
The subnetwork name or self_link to attach instances to. If null, and using a
shared VPC configuration (e.g. subnetwork_project != project_id) then a
subnetwork will be created in the subnetwork_project.
EOD
  type        = string
  default     = null
}

variable "instance_template_network" {
  description = <<EOD
The network to attach instance templates to. This is required when
using a shared VPC configuration (e.g. subnetwork_project != project_id).
EOD
  type        = string
  default     = null
}
