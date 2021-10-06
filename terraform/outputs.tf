# Copyright 2021 SchedMD LLC
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

output "cluster_name" {
  description = "Cluster name"
  value       = var.cluster_name
}

output "vpc" {
  description = "vpc details"
  value       = module.vpc
}

output "config" {
  description = "Cluster configuration details"
  value       = var.config
  sensitive   = true
}
output "controller_template" {
  description = "Controller template details"
  value       = module.controller_template
}

output "login_template" {
  description = "Login template details"
  value       = module.login_template
}

output "compute_template" {
  description = "Compute template details"
  value       = module.compute_template
}

output "partitions" {
  description = "Partition Configuration details"
  value       = var.partitions
}
