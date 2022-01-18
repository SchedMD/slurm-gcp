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

##########
# LOCALS #
##########

locals {
  example_defaults = {
    region     = module.slurm_network.network.subnets_regions[0]
    subnetwork = module.slurm_network.network.subnets_self_links[0]
  }

  slurm_cluster_defaults = merge(
    var.slurm_cluster_defaults,
    local.example_defaults,
  )

  controller_instance_config = merge(
    var.controller_instance_config,
    local.example_defaults,
  )

  compute_node_groups_defaults = merge(
    var.compute_node_groups_defaults,
    local.example_defaults,
  )

  login_node_groups_defaults = merge(
    var.login_node_groups_defaults,
    local.example_defaults,
  )
}

############
# PROVIDER #
############

provider "google" {
  project = var.project_id
  region  = var.region
}

###########
# NETWORK #
###########

module "slurm_network" {
  source = "../../../../modules/_network"

  auto_create_subnetworks = false
  network_name            = "${var.cluster_name}-default"
  project_id              = var.project_id

  subnets = [
    {
      subnet_name      = "${var.cluster_name}-default"
      subnet_ip        = "10.0.0.0/24"
      subnet_region    = var.region
      subnet_flow_logs = true
    },
  ]
}

##################
# FIREWALL RULES #
##################

module "slurm_firewall_rules" {
  source = "../../../../modules/slurm_firewall_rules"

  cluster_name = var.cluster_name
  network_name = module.slurm_network.network.network_self_link
  project_id   = var.project_id
}

#################
# SLURM CLUSTER #
#################

module "slurm_cluster" {
  source = "../../../../modules/slurm_cluster"

  cgroup_conf_tpl              = var.cgroup_conf_tpl
  cloud_parameters             = var.cloud_parameters
  cloudsql                     = var.cloudsql
  cluster_name                 = var.cluster_name
  compute_node_groups_defaults = local.compute_node_groups_defaults
  compute_d                    = var.compute_d
  controller_instance_config   = local.controller_instance_config
  controller_d                 = var.controller_d
  enable_devel                 = var.enable_devel
  jwt_key                      = var.jwt_key
  login_network_storage        = var.login_network_storage
  login_node_groups            = var.login_node_groups
  login_node_groups_defaults   = local.login_node_groups_defaults
  munge_key                    = var.munge_key
  network_storage              = var.network_storage
  partitions                   = var.partitions
  project_id                   = var.project_id
  slurmdbd_conf_tpl            = var.slurmdbd_conf_tpl
  slurm_cluster_defaults       = local.slurm_cluster_defaults
  slurm_conf_tpl               = var.slurm_conf_tpl
}
