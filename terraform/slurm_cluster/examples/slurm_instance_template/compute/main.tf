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

locals {
  slurm_cluster_name = "e${random_string.slurm_cluster_name.result}"
}

provider "google" {
  project = var.project_id
}

data "google_compute_network" "default" {
  name = "default"
}

resource "random_string" "slurm_cluster_name" {
  length  = 8
  upper   = false
  special = false
}

module "slurm_compute_template" {
  source = "../../../modules/slurm_instance_template"

  network             = data.google_compute_network.default.self_link
  project_id          = var.project_id
  slurm_cluster_name  = local.slurm_cluster_name
  slurm_instance_role = "compute"
}
