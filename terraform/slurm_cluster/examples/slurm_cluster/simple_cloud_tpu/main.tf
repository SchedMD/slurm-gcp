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
  nodeset_tpu = [
    {
      nodeset_name           = "v2x8"
      node_type              = "v2-8"
      tf_version             = "2.12.0"
      zone                   = var.zone
      preemptible            = true
      preserve_tpu           = true
      enable_public_ip       = true
      node_count_dynamic_max = 20
      node_count_static      = 0
      subnetwork             = data.google_compute_subnetwork.default.self_link
      service_account        = module.slurm_sa_iam["compute"].service_account
    },
  ]

  partitions = [
    {
      partition_conf = {
        Default = "YES"
      }
      partition_name        = "debug"
      partition_nodeset_tpu = [local.nodeset_tpu[0].nodeset_name]
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
  partitions                 = local.partitions
  nodeset_tpu                = local.nodeset_tpu
  project_id                 = var.project_id

  depends_on = [
    module.slurm_firewall_rules,
    module.slurm_sa_iam,
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
