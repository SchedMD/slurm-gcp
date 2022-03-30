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

##############
# Google API #
##############

module "project_services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 12.0"

  project_id = var.project_id

  activate_apis = flatten([
    "compute.googleapis.com",
    "iam.googleapis.com",
    var.enable_reconfigure ? ["pubsub.googleapis.com"] : [],
  ])

  enable_apis                 = true
  disable_services_on_destroy = false
}

#################
# SLURM CLUSTER #
#################

module "slurm_cluster" {
  source = "../../../../modules/slurm_cluster"

  cloud_parameters         = var.cloud_parameters
  slurm_cluster_name       = var.slurm_cluster_name
  compute_d                = var.compute_d
  controller_hybrid_config = var.controller_hybrid_config
  enable_devel             = var.enable_devel
  enable_bigquery_load     = var.enable_bigquery_load
  enable_reconfigure       = var.enable_reconfigure
  epilog_d                 = var.epilog_d
  enable_hybrid            = true
  partitions               = var.partitions
  project_id               = var.project_id
  prolog_d                 = var.prolog_d
}
