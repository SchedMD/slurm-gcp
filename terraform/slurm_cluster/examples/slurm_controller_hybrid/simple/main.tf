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

data "google_compute_subnetwork" "default" {
  name   = "default"
  region = var.region
}

resource "random_string" "slurm_cluster_name" {
  length  = 8
  upper   = false
  special = false
}

module "slurm_files" {
  source = "../../../modules/slurm_files"

  bucket_name   = var.bucket_name
  enable_hybrid = true
  partitions = [
    module.slurm_partition0,
    module.slurm_partition1,
  ]
  nodeset = [
    module.slurm_nodeset0,
    module.slurm_nodeset1,
  ]
  project_id         = var.project_id
  slurm_cluster_name = local.slurm_cluster_name
  # hybrid
  slurm_control_host = "localhost"
  slurm_bin_dir      = "/usr/local/bin"
  slurm_log_dir      = "./log"
  output_dir         = "./etc"
}

module "slurm_compute0" {
  source = "../../../modules/slurm_instance_template"

  project_id         = var.project_id
  machine_type       = "c2-standard-4"
  slurm_cluster_name = local.slurm_cluster_name
  slurm_bucket_path  = module.slurm_files.slurm_bucket_path
  subnetwork         = data.google_compute_subnetwork.default.self_link
}

module "slurm_nodeset0" {
  source = "../../../modules/slurm_nodeset"

  nodeset_name                = "c2s4"
  node_count_dynamic_max      = 20
  instance_template_self_link = module.slurm_compute0.instance_template.self_link
  subnetwork_self_link        = data.google_compute_subnetwork.default.self_link
}

module "slurm_partition0" {
  source = "../../../modules/slurm_partition"

  partition_name = "debug"
  partition_conf = {
    Default = "YES"
  }
  partition_nodeset = [module.slurm_nodeset0.nodeset_name]
}

module "slurm_compute1" {
  source = "../../../modules/slurm_instance_template"

  project_id   = var.project_id
  machine_type = "n1-standard-4"
  gpu = {
    count = 1
    type  = "nvidia-tesla-v100"
  }
  slurm_cluster_name = local.slurm_cluster_name
  slurm_bucket_path  = module.slurm_files.slurm_bucket_path
  subnetwork         = data.google_compute_subnetwork.default.self_link
}

module "slurm_nodeset1" {
  source = "../../../modules/slurm_nodeset"

  nodeset_name                = "v100"
  node_count_dynamic_max      = 5
  instance_template_self_link = module.slurm_compute1.instance_template.self_link
  subnetwork_self_link        = data.google_compute_subnetwork.default.self_link
}

module "slurm_partition1" {
  source = "../../../modules/slurm_partition"

  partition_name    = "gpu"
  partition_nodeset = [module.slurm_nodeset1.nodeset_name]
}

module "slurm_controller_hybrid" {
  source = "../../../modules/slurm_controller_hybrid"

  config             = module.slurm_files.config
  project_id         = var.project_id
  slurm_cluster_name = local.slurm_cluster_name
}
