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
  region  = var.region
}

data "google_compute_subnetwork" "default" {
  name   = "default"
  region = var.region
}

module "slurm_files" {
  source = "../../../modules/slurm_files"

  bucket_name = var.bucket_name
  partitions = [
    module.slurm_partition,
  ]
  project_id         = var.project_id
  slurm_cluster_name = var.slurm_cluster_name
}

module "slurm_compute_sa" {
  source = "../../../../slurm_sa_iam"

  account_type       = "compute"
  project_id         = var.project_id
  slurm_cluster_name = var.slurm_cluster_name
}

module "compute" {
  source = "../../../modules/slurm_instance_template"

  project_id         = var.project_id
  machine_type       = "c2-standard-4"
  service_account    = module.slurm_compute_sa.service_account
  slurm_cluster_name = var.slurm_cluster_name
  slurm_bucket_path  = module.slurm_files.slurm_bucket_path
  subnetwork         = data.google_compute_subnetwork.default.self_link
}

module "slurm_nodeset" {
  source = "../../../modules/slurm_nodeset"

  nodeset_name                = "c2s4"
  node_count_dynamic_max      = 20
  instance_template_self_link = module.compute.instance_template.self_link
  subnetwork_self_link        = data.google_compute_subnetwork.default.self_link
}

module "slurm_partition" {
  source = "../../../modules/slurm_partition"

  partition_name = "debug"
  partition_conf = {
    Default = "YES"
  }
  partition_nodeset = [module.slurm_nodeset.nodeset_name]
}
