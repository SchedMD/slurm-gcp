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
  cloud_parameters = merge(var.cloud_parameters, {
    no_comma_params = false
  })
}

############
# PROVIDER #
############

provider "google" {
  project = var.project_id
  region  = var.region
}

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
  ]

  enable_apis                 = true
  disable_services_on_destroy = false
}

#################
# SLURM CLUSTER #
#################

module "slurm_cluster" {
  source = "../../../../../slurm_cluster"

  cgroup_conf_tpl              = var.cgroup_conf_tpl
  cloud_parameters             = local.cloud_parameters
  cloudsql                     = var.cloudsql
  slurm_cluster_name           = var.slurm_cluster_name
  compute_startup_scripts      = var.compute_startup_scripts
  controller_instance_config   = var.controller_instance_config
  controller_startup_scripts   = var.controller_startup_scripts
  enable_devel                 = var.enable_devel
  enable_bigquery_load         = var.enable_bigquery_load
  enable_cleanup_compute       = var.enable_cleanup_compute
  enable_cleanup_subscriptions = var.enable_cleanup_subscriptions
  enable_reconfigure           = var.enable_reconfigure
  epilog_scripts               = var.epilog_scripts
  login_startup_scripts        = var.login_startup_scripts
  login_network_storage        = var.login_network_storage
  login_nodes                  = var.login_nodes
  network_storage              = var.network_storage
  partitions                   = var.partitions
  project_id                   = var.project_id
  prolog_scripts               = var.prolog_scripts
  slurmdbd_conf_tpl            = var.slurmdbd_conf_tpl
  slurm_conf_tpl               = var.slurm_conf_tpl

  depends_on = [
    # Ensure services are enabled
    module.project_services,
  ]
}
