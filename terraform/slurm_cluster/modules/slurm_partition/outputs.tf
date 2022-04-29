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

output "partition" {
  description = "Partition for slurm controller."
  value       = local.partition
}

output "partition_nodes" {
  description = "Partition for slurm controller."
  value       = local.partition_nodes
}

output "compute_list" {
  description = "List of compute node hostnames."
  value       = local.compute_list
}
