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

output "slurm_cluster_id" {
  description = "Slurm cluster ID."
  value       = local.slurm_cluster_id
}

output "slurm_partition" {
  description = "Slurm partition details."
  value = (
    var.enable_hybrid
    ? module.slurm_controller_hybrid[0].partitions
    : module.slurm_controller_instance[0].partitions
  )
}
