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

##########
# LOCALS #
##########

locals {
  controller_instance_config = {
    disk_size_gb    = 32
    disk_type       = "pd-standard"
    machine_type    = "n1-standard-4"
    service_account = module.slurm_sa_iam["controller"].service_account
    subnetwork      = data.google_compute_subnetwork.default.self_link
  }

  login_nodes = [
    {
      group_name = "l0"

      disk_size_gb    = 32
      disk_type       = "pd-standard"
      machine_type    = "n1-standard-2"
      service_account = module.slurm_sa_iam["login"].service_account
      subnetwork      = data.google_compute_subnetwork.default.self_link
    }
  ]

  nodeset_dyn = [
    {
      nodeset_name    = "dyn"
      nodeset_feature = local.node_feature
    },
  ]

  partitions = [
    {
      partition_conf = {
        Default     = "YES"
        SuspendTime = "INFINITE"
      }
      partition_name        = "debug"
      partition_nodeset_dyn = [local.nodeset_dyn[0].nodeset_name]
    },
  ]

  node_feature = "dyn0"
}

############
# PROVIDER #
############

provider "google" {
  project = var.project_id
  region  = var.region
}

########
# DATA #
########

data "google_compute_subnetwork" "default" {
  name = "default"
}

#################
# SLURM CLUSTER #
#################

module "slurm_cluster" {
  source = "../../../../slurm_cluster"

  region                     = var.region
  slurm_cluster_name         = var.slurm_cluster_name
  controller_instance_config = local.controller_instance_config
  login_nodes                = local.login_nodes
  nodeset_dyn                = local.nodeset_dyn
  partitions                 = local.partitions
  project_id                 = var.project_id

  depends_on = [
    module.slurm_firewall_rules,
    module.slurm_sa_iam,
  ]
}

#################
# DYNAMIC NODES #
#################

module "dynamic_node_instance_template" {
  source = "../../../../slurm_cluster/modules/slurm_instance_template"

  metadata = {
    slurmd_feature = local.node_feature
  }
  project_id          = var.project_id
  name_prefix         = "dynamic"
  region              = var.region
  slurm_bucket_path   = module.slurm_cluster.slurm_bucket_path
  slurm_cluster_name  = var.slurm_cluster_name
  slurm_instance_role = "compute"
  subnetwork          = data.google_compute_subnetwork.default.self_link
  tags                = [var.slurm_cluster_name]
}

module "dynamic_node" {
  source = "../../../../slurm_cluster/modules/_slurm_instance"

  instance_template   = module.dynamic_node_instance_template.self_link
  num_instances       = 2
  hostname            = "${var.slurm_cluster_name}-dynamic"
  project_id          = var.project_id
  region              = var.region
  slurm_cluster_name  = var.slurm_cluster_name
  slurm_instance_role = "compute"
  subnetwork          = data.google_compute_subnetwork.default.self_link

  depends_on = [
    module.slurm_cluster,
  ]
}

##################
# FIREWALL RULES #
##################

module "slurm_firewall_rules" {
  source = "../../../../slurm_firewall_rules"

  slurm_cluster_name = var.slurm_cluster_name
  network_name       = data.google_compute_subnetwork.default.network
  project_id         = var.project_id
}

##########################
# SERVICE ACCOUNTS & IAM #
##########################

module "slurm_sa_iam" {
  source = "../../../../slurm_sa_iam"

  for_each = toset(["controller", "login", "compute"])

  account_type       = each.value
  slurm_cluster_name = var.slurm_cluster_name
  project_id         = var.project_id
}
