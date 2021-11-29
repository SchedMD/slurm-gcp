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
  source = "../../../modules/_network"

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
  source = "../../../modules/slurm_firewall_rules"

  project_id   = var.project_id
  network_name = module.network.network.network_name
  cluster_name = var.cluster_name
}

######################
# CONTROLLER: HYBRID #
######################

module "slurm_controller_hybrid" {
  source = "../../../modules/slurm_controller_hybrid"

  project_id = var.project_id

  ### slurm ###
  cluster_name = var.cluster_name
  template_map = {
    "cpu" = module.compute_instance_template.instance_template.self_link
  }
  partitions = {
    "debug" = {
      conf = {
        Default = "YES"
      }
      exclusive       = false
      network_storage = []
      nodes = [{
        count_dynamic = 5
        count_static  = 1
        template      = "cpu"
      }]
      placement_groups = false
      region           = null
      subnetwork       = module.network.network.subnets_self_links[0]
      zone_policy      = {}
    }
  }

  output_dir       = "./config"
  cloud_parameters = var.cloud_parameters

  depends_on = [
    module.slurm_firewall_rules,
  ]
}

#####################
# COMPUTE: TEMPLATE #
#####################

module "compute_instance_template" {
  source = "../../../modules/slurm_instance_template"

  project_id = var.project_id
  subnetwork = module.network.network.subnets_self_links[0]

  slurm_cluster_id = module.slurm_controller_hybrid.slurm_cluster_id
}
