#
# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

provider "google" {
  project = var.project
  region  = var.region
}

module "slurm_cluster_network" {
  source = "../../modules/network"

  cluster_name       = var.cluster_name
  disable_public_ips = var.disable_public_ips
  region             = var.region
}

module "slurm_cluster_controller" {
  source = "../../modules/controller"

  cluster_name  = var.cluster_name
  project       = var.project
  region        = var.region
  network       = module.slurm_cluster_network.cluster_network_self_link
  partitions    = var.partitions
  subnet        = module.slurm_cluster_network.cluster_subnet_name
  users         = var.users
}

module "slurm_cluster_login" {
  source = "../../modules/login"

  cluster_name      = var.cluster_name
  controller_name   = module.slurm_cluster_controller.controller_node_name
  network           = module.slurm_cluster_network.cluster_network_self_link
  nfs_apps_server   = module.slurm_cluster_controller.controller_node_name
  nfs_home_server   = module.slurm_cluster_controller.controller_node_name
  node_count        = 1
  subnet            = module.slurm_cluster_network.cluster_subnet_name
 }

module "slurm_cluster_compute" {
  source = "../../modules/compute"

  cluster_name      = var.cluster_name
  controller_name   = module.slurm_cluster_controller.controller_node_name
  network           = module.slurm_cluster_network.cluster_subnet_self_link
  project           = var.project
  nfs_apps_server   = module.slurm_cluster_controller.controller_node_name
  nfs_home_server   = module.slurm_cluster_controller.controller_node_name
  subnet            = module.slurm_cluster_network.cluster_subnet_name
}

