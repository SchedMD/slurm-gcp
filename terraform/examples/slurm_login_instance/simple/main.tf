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

provider "google" {
  project = var.project_id
}

resource "random_string" "cluster_name" {
  length  = 8
  lower   = true
  upper   = false
  special = false
  number  = false
}

resource "random_uuid" "cluster_id" {
}

data "google_compute_subnetwork" "default" {
  name   = "default"
  region = var.region
}

module "slurm_instance_template" {
  source = "../../../modules/slurm_instance_template"

  project_id = var.project_id
  subnetwork = data.google_compute_subnetwork.default.self_link

  cluster_id = random_uuid.cluster_id.result
}

module "slurm_login_instance" {
  source = "../../../modules/slurm_login_instance"

  instance_template = module.slurm_instance_template.instance_template.self_link
  subnetwork        = data.google_compute_subnetwork.default.self_link

  cluster_name = random_string.cluster_name.result
  cluster_id   = random_uuid.cluster_id.result
}
