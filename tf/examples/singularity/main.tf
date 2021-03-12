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
  network_name                  = var.network_name
  partitions                    = var.partitions
  shared_vpc_host_project       = var.shared_vpc_host_project
  subnetwork_name               = var.subnetwork_name

  project = var.project
  region  = local.region
}

module "slurm_cluster_controller" {
  source = "../../modules/controller"

  boot_disk_size                = var.controller_disk_size_gb
  boot_disk_type                = var.controller_disk_type
  image                         = var.controller_image
  instance_template             = var.controller_instance_template
  cluster_name                  = var.cluster_name
  compute_node_scopes           = var.compute_node_scopes
  compute_node_service_account  = var.compute_node_service_account
  disable_compute_public_ips    = var.disable_compute_public_ips
  disable_controller_public_ips = var.disable_controller_public_ips
  labels                        = var.controller_labels
  login_network_storage         = var.login_network_storage
  login_node_count              = var.login_node_count
  machine_type                  = var.controller_machine_type
  munge_key                     = var.munge_key
  jwt_key                       = var.jwt_key
  network_storage               = var.network_storage
  partitions                    = var.partitions
  project                       = var.project
  region                        = local.region
  secondary_disk                = var.controller_secondary_disk
  secondary_disk_size           = var.controller_secondary_disk_size
  secondary_disk_type           = var.controller_secondary_disk_type
  shared_vpc_host_project       = var.shared_vpc_host_project
  scopes                        = var.controller_scopes
  service_account               = var.controller_service_account
  subnet_depend                 = module.slurm_cluster_network.subnet_depend
  subnetwork_name               = var.subnetwork_name
  suspend_time                  = var.suspend_time
  zone                          = var.zone
}

module "slurm_cluster_login" {
  source = "../../modules/login"

  boot_disk_size            = var.login_disk_size_gb
  boot_disk_type            = var.login_disk_type
  image                     = var.login_image
  instance_template         = var.login_instance_template
  cluster_name              = var.cluster_name
  controller_name           = module.slurm_cluster_controller.controller_node_name
  controller_secondary_disk = var.controller_secondary_disk
  disable_login_public_ips  = var.disable_login_public_ips
  labels                    = var.login_labels
  login_network_storage     = var.login_network_storage
  machine_type              = var.login_machine_type
  node_count                = var.login_node_count
  region                    = local.region
  scopes                    = var.login_node_scopes
  service_account           = var.login_node_service_account
  munge_key                 = var.munge_key
  network_storage           = var.network_storage
  shared_vpc_host_project   = var.shared_vpc_host_project
  subnet_depend             = module.slurm_cluster_network.subnet_depend
  subnetwork_name           = var.subnetwork_name
  zone                      = var.zone
}

module "slurm_cluster_compute" {
  source = "../../modules/compute"

  cluster_name               = var.cluster_name
  controller_name            = module.slurm_cluster_controller.controller_node_name
  disable_compute_public_ips = var.disable_compute_public_ips
  network_storage            = var.network_storage
  partitions                 = var.partitions
  project                    = var.project
  region                     = local.region
  scopes                     = var.compute_node_scopes
  service_account            = var.compute_node_service_account
  shared_vpc_host_project    = var.shared_vpc_host_project
  subnet_depend              = module.slurm_cluster_network.subnet_depend
  subnetwork_name            = var.subnetwork_name
  zone                       = var.zone
}

