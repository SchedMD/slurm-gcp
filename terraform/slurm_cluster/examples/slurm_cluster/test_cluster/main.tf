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

##############
# Google API #
##############

module "project_services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 12.0"

  project_id = var.project_id

  activate_apis = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com",
  ]

  enable_apis                 = true
  disable_services_on_destroy = false
}

###########
# NETWORK #
###########

locals {
  network_name = "${var.slurm_cluster_name}-default"

  subnets = [for s in var.subnets : merge(s, {
    subnet_name           = local.network_name
    subnet_region         = lookup(s, "subnet_region", var.region)
    subnet_private_access = true
  })]
}

module "slurm_network" {
  source = "../../../../_network"

  count = var.create_network ? 1 : 0

  auto_create_subnetworks = false
  mtu                     = var.mtu
  network_name            = local.network_name
  project_id              = var.project_id

  subnets = local.subnets

  depends_on = [
    module.project_services,
  ]
}

##################
# FIREWALL RULES #
##################

module "slurm_firewall_rules" {
  source = "../../../../slurm_firewall_rules"

  count = var.create_network ? 1 : 0

  slurm_cluster_name = var.slurm_cluster_name
  network_name       = module.slurm_network[0].network.network_self_link
  project_id         = var.project_id

  depends_on = [
    module.project_services,
  ]
}

##########################
# SERVICE ACCOUNTS & IAM #
##########################

module "slurm_sa_iam" {
  source = "../../../../slurm_sa_iam"

  for_each = var.create_service_accounts ? toset(["controller", "login", "compute"]) : []

  account_type       = each.value
  slurm_cluster_name = var.slurm_cluster_name
  project_id         = var.project_id

  depends_on = [
    module.project_services,
  ]
}

#################
# SLURM CLUSTER #
#################

locals {
  controller_instance_config = merge(
    var.controller_instance_config,
    {
      service_account      = var.create_service_accounts ? module.slurm_sa_iam["controller"].service_account : var.controller_instance_config.service_account
      source_image         = can(coalesce(var.controller_instance_config.source_image)) ? var.controller_instance_config.source_image : var.source_image
      source_image_family  = can(coalesce(var.controller_instance_config.source_image_family)) ? var.controller_instance_config.source_image_family : var.source_image_family
      source_image_project = can(coalesce(var.controller_instance_config.source_image_project)) ? var.controller_instance_config.source_image_project : var.source_image_project
      subnetwork           = coalesce(try(module.slurm_network[0].network.network_name, null), var.controller_instance_config.subnetwork, var.subnetwork)
      subnetwork_project   = coalesce(var.subnetwork_project, var.project_id)
    }
  )

  nodeset = [for x in var.nodeset : merge(x, {
    service_account      = var.create_service_accounts ? module.slurm_sa_iam["compute"].service_account : x.service_account
    source_image         = can(coalesce(x.source_image)) ? x.source_image : var.source_image
    source_image_family  = can(coalesce(x.source_image_family)) ? x.source_image_family : var.source_image_family
    source_image_project = can(coalesce(x.source_image_project)) ? x.source_image_project : var.source_image_project
    subnetwork           = coalesce(try(module.slurm_network[0].network.network_name, null), x.subnetwork, var.subnetwork)
    subnetwork_project   = coalesce(x.subnetwork_project, var.subnetwork_project, var.project_id)
  })]

  nodeset_tpu = [for x in var.nodeset_tpu : merge(x, {
    service_account = var.create_service_accounts ? module.slurm_sa_iam["compute"].service_account : x.service_account
    subnetwork      = coalesce(try(module.slurm_network[0].network.network_name, null), x.subnetwork, var.subnetwork)
  })]

  login_nodes = [
    for x in var.login_nodes : merge(x, {
      service_account      = var.create_service_accounts ? module.slurm_sa_iam["login"].service_account : x.service_account
      source_image         = can(coalesce(x.source_image)) ? x.source_image : var.source_image
      source_image_family  = can(coalesce(x.source_image_family)) ? x.source_image_family : var.source_image_family
      source_image_project = can(coalesce(x.source_image_project)) ? x.source_image_project : var.source_image_project
      subnetwork           = coalesce(try(module.slurm_network[0].network.network_name, null), x.subnetwork, var.subnetwork)
      subnetwork_project   = coalesce(x.subnetwork_project, var.subnetwork_project, var.project_id)
    })
  ]
}

module "slurm_cluster" {
  source = "../../../../slurm_cluster"

  create_bucket                      = var.create_bucket
  region                             = var.region
  bucket_name                        = var.bucket_name
  bucket_dir                         = var.bucket_dir
  cgroup_conf_tpl                    = var.cgroup_conf_tpl
  cloud_parameters                   = var.cloud_parameters
  cloudsql                           = var.cloudsql
  disable_default_mounts             = var.disable_default_mounts
  enable_hybrid                      = var.enable_hybrid
  enable_login                       = var.enable_login
  slurm_cluster_name                 = var.slurm_cluster_name
  compute_startup_scripts_timeout    = var.compute_startup_scripts_timeout
  compute_startup_scripts            = var.compute_startup_scripts
  controller_hybrid_config           = var.controller_hybrid_config
  controller_instance_config         = local.controller_instance_config
  controller_startup_scripts_timeout = var.controller_startup_scripts_timeout
  controller_startup_scripts         = var.controller_startup_scripts
  enable_devel                       = var.enable_devel
  enable_bigquery_load               = var.enable_bigquery_load
  enable_cleanup_compute             = var.enable_cleanup_compute
  epilog_scripts                     = var.epilog_scripts
  login_startup_scripts_timeout      = var.login_startup_scripts_timeout
  login_startup_scripts              = var.login_startup_scripts
  login_network_storage              = var.login_network_storage
  login_nodes                        = local.login_nodes
  network_storage                    = var.network_storage
  nodeset                            = local.nodeset
  nodeset_dyn                        = var.nodeset_dyn
  nodeset_tpu                        = local.nodeset_tpu
  partitions                         = var.partitions
  project_id                         = var.project_id
  prolog_scripts                     = var.prolog_scripts
  slurmdbd_conf_tpl                  = var.slurmdbd_conf_tpl
  slurm_conf_tpl                     = var.slurm_conf_tpl

  depends_on = [
    module.project_services,
    module.slurm_network,
    module.slurm_firewall_rules,
    module.slurm_sa_iam,
  ]
}
