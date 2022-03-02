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

  cloud_parameters         = var.cloud_parameters
  slurm_cluster_name       = var.slurm_cluster_name
  compute_d                = var.compute_d
  controller_hybrid_config = var.controller_hybrid_config
  enable_devel             = var.enable_devel
  enable_bigquery_load     = var.enable_bigquery_load
  epilog_d                 = var.epilog_d
  enable_hybrid            = true
  login_network_storage    = var.login_network_storage
  munge_key                = var.munge_key
  network_storage          = var.network_storage
  partitions               = var.partitions
  project_id               = var.project_id
  prolog_d                 = var.prolog_d
}
