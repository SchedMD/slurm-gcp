#
# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "region" {
  description = "Compute Platform region where the notebook server will be located"
  default     = "us-central1"
}

variable "cluster_name" {
  description = "Name of the Slurm cluster"
}

variable "cluster_network_cidr_range" {
  description = "CIDR range for cluster network"
  default     = "10.10.0.0/16"
}

variable "private_ip_google_access" {
  description = "Determines whether instances can access Google services w/o external addresses"
  default     = true
}

variable "disable_login_public_ips" {
  description = "If set to true, create Cloud NAT gateway and enable IAP FW rules"
  default     = false
}

variable "disable_controller_public_ips" {
  description = "If set to true, create Cloud NAT gateway and enable IAP FW rules"
  default     = false
}

variable "disable_compute_public_ips" {
  description = "If set to true, create Cloud NAT gateway and enable IAP FW rules"
  default     = false
}

output "cluster_network_self_link" {
  value = google_compute_network.cluster_network.self_link
}

output "cluster_subnet_self_link" {
  value = google_compute_subnetwork.cluster_subnet.self_link
}

output "cluster_network_name" {
  value = google_compute_network.cluster_network.name
}

output "cluster_subnet_name" {
  value = google_compute_subnetwork.cluster_subnet.name
}
