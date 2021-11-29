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

############
# INSTANCE #
############

output "slurm_controller_instance" {
  description = "Controller instance"
  value       = module.slurm_controller_instance
}

#########
# SLURM #
#########

output "cluster_name" {
  description = "Cluster name for resource naming and slurm accounting."
  value       = local.cluster_name
}

output "slurm_cluster_id" {
  description = "Cluster ID for cluster resource labeling."
  value       = local.slurm_cluster_id
}

output "munge_key" {
  description = "Cluster munge authentication key."
  value       = local.munge_key
}

output "jwt_key" {
  description = "Cluster jwt authentication key."
  value       = local.jwt_key
}

output "serf_keys" {
  description = "Cluster serf agent keys."
  value       = local.serf_keys
}

output "template_map" {
  description = "Compute template map."
  value       = local.template_map
}

output "partitions" {
  description = "Cluster partitions."
  value       = local.partitions
}

output "compute_instance_templates" {
  description = "Compute instance template details."
  value       = module.slurm_controller_common.compute_instance_templates
}

output "partition_subnetworks" {
  description = "Partition subnetwork details."
  value       = module.slurm_controller_common.partition_subnetworks
}
