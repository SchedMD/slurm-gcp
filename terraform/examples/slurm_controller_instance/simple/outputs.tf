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

output "slurm_controller_instance" {
  description = "Slurm controller instance self_links"
  value       = module.slurm_controller_instance.slurm_controller_instance.instances_self_links
}

output "slurm_cluster_name" {
  description = "Slurm cluster name"
  value       = module.slurm_controller_instance.slurm_cluster_name
}
