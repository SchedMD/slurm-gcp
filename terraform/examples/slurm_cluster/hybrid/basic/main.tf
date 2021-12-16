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
}

###########
# NETWORK #
###########

module "network" {
  source = "../../../../modules/_network"

  project_id = var.project_id

  network_name = "${var.cluster_name}-network"
  subnets = [
    {
      subnet_name   = "${var.cluster_name}-subnetwork"
      subnet_ip     = "10.0.0.0/20"
      subnet_region = var.region

      subnet_private_access = true
      subnet_flow_logs      = true
    },
  ]
}

##################
# FIREWALL RULES #
##################

module "slurm_firewall_rules" {
  source = "../../../../modules/slurm_firewall_rules"

  project_id   = var.project_id
  network_name = module.network.network.network_name
  cluster_name = var.cluster_name
}

######################
# COMPUTE: TEMPLATES #
######################

module "slurm_compute_template" {
  source = "../../../../modules/slurm_compute_template"

  cluster_name     = var.cluster_name
  project_id       = var.project_id
  slurm_cluster_id = module.slurm_controller_hybrid.slurm_cluster_id
  subnetwork       = module.network.network.subnets_self_links[0]
}

###################
# SLURM PARTITION #
###################

module "slurm_partition" {
  source = "../../../../modules/slurm_partition"

  partition_name = "debug"
  partition_conf = {
    Default = "YES"
  }
  partition_nodes = [
    {
      node_group_name   = "n1"
      instance_template = module.slurm_compute_template.self_link
      count_static      = 0
      count_dynamic     = 20
    },
  ]
  subnetwork = module.network.network.subnets_self_links[0]
}

######################
# CONTROLLER: HYBRID #
######################

module "slurm_controller_hybrid" {
  source = "../../../../modules/slurm_controller_hybrid"

  cloud_parameters = var.cloud_parameters
  cluster_name     = var.cluster_name
  output_dir       = "./config"
  partitions = [
    module.slurm_partition.partition,
  ]
  project_id = var.project_id

  depends_on = [
    module.slurm_firewall_rules,
  ]
}
