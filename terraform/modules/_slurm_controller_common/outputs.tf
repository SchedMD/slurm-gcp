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

output "munge_key" {
  description = "Cluster munge authentication key."
  value       = local.munge_key
  sensitive   = true
}

output "jwt_key" {
  description = "Cluster jwt authentication key."
  value       = local.jwt_key
  sensitive   = true
}

output "template_map" {
  description = "Compute template map."
  value       = var.template_map
}

output "partitions" {
  description = "Cluster partitions."
  value       = var.partitions
}

output "compute_instance_templates" {
  description = "Compute instance template details."
  value       = data.google_compute_instance_template.compute_instance_templates
}

output "partition_subnetworks" {
  description = "Partition subnetwork details."
  value       = data.google_compute_subnetwork.partition_subnetworks
}

output "pubsub" {
  description = "Slurm Pub/Sub details."
  value       = module.pubsub
}

output "pubsub_topic" {
  description = "Slurm Pub/Sub topic ID."
  value       = google_pubsub_topic.this.name
}
