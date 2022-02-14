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

############
# PROVIDER #
############

provider "google" {
  project = var.project_id
  region  = var.region
}

#################
# SLURM CLUSTER #
#################

module "slurm_cluster" {
  source = "../../../../modules/slurm_cluster"

  cgroup_conf_tpl            = var.cgroup_conf_tpl
  cloud_parameters           = var.cloud_parameters
  cloudsql                   = var.cloudsql
  slurm_cluster_name         = var.slurm_cluster_name
  compute_d                  = var.compute_d
  controller_instance_config = var.controller_instance_config
  controller_d               = var.controller_d
  enable_devel               = var.enable_devel
  epilog_d                   = var.epilog_d
  jwt_key                    = var.jwt_key
  login_network_storage      = var.login_network_storage
  login_nodes                = var.login_nodes
  munge_key                  = var.munge_key
  network_storage            = var.network_storage
  partitions                 = var.partitions
  project_id                 = var.project_id
  prolog_d                   = var.prolog_d
  slurmdbd_conf_tpl          = var.slurmdbd_conf_tpl
  slurm_conf_tpl             = var.slurm_conf_tpl
}

##################
# FIREWALL RULES #
##################

module "slurm_firewall_rules" {
  source = "../../../../modules/slurm_firewall_rules"

  slurm_cluster_name = var.slurm_cluster_name
  network_name       = var.firewall_network_name
  project_id         = var.project_id
}
