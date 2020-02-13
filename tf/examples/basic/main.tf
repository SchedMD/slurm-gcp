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

locals {
  region = join("-", slice(split("-", var.zone), 0, 2))
}

provider "google" {
  project = var.project
  region  = local.region
}

module "slurm_cluster_network" {
  source = "../../modules/network"

  cluster_name                  = var.cluster_name
  disable_login_public_ips      = var.disable_login_public_ips
  disable_controller_public_ips = var.disable_controller_public_ips
  disable_compute_public_ips    = var.disable_compute_public_ips

  region = local.region
}

module "slurm_cluster_controller" {
  source = "../../modules/controller"

  cluster_name                  = var.cluster_name
  compute_node_scopes           = var.compute_node_scopes
  compute_node_service_account  = var.compute_node_service_account
  controller_secondary_disk     = var.controller_secondary_disk
  disable_compute_public_ips    = var.disable_compute_public_ips
  disable_controller_public_ips = var.disable_controller_public_ips
  login_network_storage         = var.login_network_storage
  login_node_count              = var.login_node_count
  munge_key                     = var.munge_key
  network                       = module.slurm_cluster_network.cluster_network_self_link
  network_storage               = var.network_storage
  ompi_version                  = var.ompi_version
  partitions                    = var.partitions
  project                       = var.project
  region                        = local.region
  shared_vpc_host_project       = var.shared_vpc_host_project
  slurm_version                 = var.slurm_version
  subnet                        = module.slurm_cluster_network.cluster_subnet_name
  suspend_time                  = var.suspend_time
  vpc_subnet                    = var.vpc_subnet
  zone                          = var.zone
}

module "slurm_cluster_login" {
  source = "../../modules/login"

  cluster_name              = var.cluster_name
  controller_name           = module.slurm_cluster_controller.controller_node_name
  controller_secondary_disk = var.controller_secondary_disk
  disable_login_public_ips  = var.disable_login_public_ips
  login_network_storage     = var.login_network_storage
  node_count                = var.login_node_count
  scopes                    = var.login_node_scopes
  service_account           = var.login_node_service_account
  munge_key                 = var.munge_key
  network                   = module.slurm_cluster_network.cluster_network_self_link
  network_storage           = var.network_storage
  ompi_version              = var.ompi_version
  subnet                    = module.slurm_cluster_network.cluster_subnet_name
  zone                      = var.zone
}

module "slurm_cluster_compute" {
  source = "../../modules/compute"

  cluster_name               = var.cluster_name
  scopes                     = var.compute_node_scopes
  service_account            = var.compute_node_service_account
  controller_name            = module.slurm_cluster_controller.controller_node_name
  disable_compute_public_ips = var.disable_compute_public_ips
  network                    = module.slurm_cluster_network.cluster_subnet_self_link
  network_storage            = var.network_storage
  partitions                 = var.partitions
  project                    = var.project
  subnet                     = module.slurm_cluster_network.cluster_subnet_name
  zone                       = var.zone
}

