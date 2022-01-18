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
  slurm_cluster_defaults = {
    network    = data.google_compute_subnetwork.this.network
    subnetwork = data.google_compute_subnetwork.this.self_link
  }

  login_node_groups = [
    {
      group_name    = "l0"
      num_instances = 1
    }
  ]

  partitions = [
    {
      partition_name = "default"
      compute_node_groups = [
        {
          count_dynamic = 1
          count_static  = 0
          group_name    = "default"
        },
      ]
      cluster_name = var.cluster_name
      project_id   = var.project_id
    },
  ]
}

############
# PROVIDER #
############

provider "google" {
  project = var.project_id
  region  = var.region
}

####################
# DATA: SUBNETWORK #
####################

data "google_compute_subnetwork" "this" {
  name    = var.subnetwork
  project = var.subnetwork_project
}

################
# DATA: SCRIPT #
################

data "local_file" "winbind_sh" {
  filename = "./scripts/winbind.sh"
}

#################
# SLURM CLUSTER #
#################

module "slurm_cluster" {
  source = "../../../../modules/slurm_cluster"

  cluster_name           = var.cluster_name
  compute_d              = [data.local_file.winbind_sh]
  controller_d           = [data.local_file.winbind_sh]
  login_node_groups      = local.login_node_groups
  partitions             = local.partitions
  project_id             = var.project_id
  slurm_cluster_defaults = local.slurm_cluster_defaults
}

##################
# FIREWALL RULES #
##################

module "slurm_firewall_rules" {
  source = "../../../../modules/slurm_firewall_rules"

  cluster_name = var.cluster_name
  network_name = data.google_compute_subnetwork.this.network
  project_id   = var.project_id
}
