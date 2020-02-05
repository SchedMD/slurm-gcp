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

variable "cluster_name" {}
variable "disable_login_public_ips" {}
variable "disable_controller_public_ips" {}
variable "disable_compute_public_ips" {}

variable "partitions" {
  type = list(object({
              name                 = string,
              machine_type         = string,
              max_node_count       = number,
              zone                 = string,
              compute_disk_type    = string,
              compute_disk_size_gb = number,
              compute_labels       = list(string),
              cpu_platform         = string,
              gpu_type             = string,
              gpu_count            = number,
              preemptible_bursting = number,
              static_node_count    = number}))
}
variable "project" {}
variable "region" {}
variable "zone" {}
variable "users" {}


output "controller_network_ips" {
  value = "${module.slurm_cluster_controller.instance_network_ips}"
}

output "login_network_ips" {
  value = "${module.slurm_cluster_login.instance_network_ips}"
}
