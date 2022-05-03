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

output "slurm_cluster_name" {
  description = "Slurm cluster name."
  value       = var.slurm_cluster_name
}

output "slurm_partition" {
  description = "Slurm partition details."
  value = (
    var.enable_hybrid
    ? module.slurm_controller_hybrid[0].partitions
    : module.slurm_controller_instance[0].partitions
  )
}

output "slurm_controller_instances" {
  description = "Slurm controller instance object details."
  value = (
    var.enable_hybrid
    ? []
    : module.slurm_controller_instance[0].slurm_controller_instances
  )
}

output "slurm_controller_instance_self_links" {
  description = "Slurm controller instance self_link."
  value = (
    var.enable_hybrid
    ? []
    : module.slurm_controller_instance[0].slurm_controller_instance.instances_details[*].self_link
  )
}

output "slurm_controller_instance_details" {
  description = "Slurm controller instance details."
  value = (
    var.enable_hybrid
    ? []
    : module.slurm_controller_instance[0].slurm_controller_instance.instances_details[*]
  )
}

output "slurm_login_instance_self_links" {
  description = "Slurm login instance self_link."
  value = flatten(values({
    for k, v in module.slurm_login_instance : k => v.slurm_login_instance.instances_self_links
  }))
}

output "slurm_login_instance_details" {
  description = "Slurm login instance details."
  value = flatten(values({
    for k, v in module.slurm_login_instance : k => v.slurm_login_instance.instances_details[*]
  }))
}
