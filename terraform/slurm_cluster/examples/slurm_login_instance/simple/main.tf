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

provider "google" {
  project = var.project_id
}

data "google_compute_subnetwork" "default" {
  name   = "default"
  region = var.region
}

resource "random_string" "slurm_cluster_name" {
  length  = 8
  upper   = false
  special = false
}

module "slurm_login_sa" {
  source = "../../../../slurm_sa_iam"

  account_type       = "compute"
  project_id         = var.project_id
  slurm_cluster_name = random_string.slurm_cluster_name.result
}

module "slurm_login_template" {
  source = "../../../modules/slurm_instance_template"

  project_id         = var.project_id
  service_account    = module.slurm_login_sa.service_account
  slurm_cluster_name = random_string.slurm_cluster_name.result
  subnetwork         = data.google_compute_subnetwork.default.self_link
}

module "slurm_login_instance" {
  source = "../../../modules/slurm_login_instance"

  instance_template  = module.slurm_login_template.instance_template.self_link
  subnetwork         = data.google_compute_subnetwork.default.self_link
  project_id         = var.project_id
  slurm_cluster_name = random_string.slurm_cluster_name.result
}
