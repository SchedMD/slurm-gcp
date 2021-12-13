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

########
# DATA #
########

data "google_compute_zones" "available" {
  project = module.network.network.project_id
  region  = module.network.network.subnets_regions[0]
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
  target_tags  = [var.cluster_name]
}

#########################
# CONTROLLER: TEMPLATES #
#########################

module "slurm_controller_instance_template" {
  source = "../../../../modules/slurm_instance_template"

  name_prefix      = "${var.cluster_name}-controller"
  project_id       = var.project_id
  slurm_cluster_id = module.slurm_controller_instance.slurm_cluster_id
  subnetwork       = module.network.network.subnets_self_links[0]
}

######################
# COMPUTE: TEMPLATES #
######################

module "slurm_compute_instance_template" {
  source = "../../../../modules/slurm_instance_template"

  name_prefix      = "${var.cluster_name}-n1"
  project_id       = var.project_id
  slurm_cluster_id = module.slurm_controller_instance.slurm_cluster_id
  subnetwork       = module.network.network.subnets_self_links[0]
  tags             = [var.cluster_name]
}

###################
# SLURM PARTITION #
###################

module "slurm_partition_0" {
  source = "../../../../modules/slurm_partition"

  partition_name = "debug"
  partition_conf = {
    Default = "YES"
  }
  partition_nodes = [
    {
      node_group_name   = "n1"
      instance_template = module.slurm_compute_instance_template.self_link
      count_static      = 0
      count_dynamic     = 20
    },
  ]
  subnetwork = module.network.network.subnets_self_links[0]
}

########################
# CONTROLLER: INSTANCE #
########################

module "slurm_controller_instance" {
  source = "../../../../modules/slurm_controller_instance"

  cluster_name      = var.cluster_name
  instance_template = module.slurm_controller_instance_template.self_link
  subnetwork        = module.network.network.subnets_self_links[0]
  zone              = data.google_compute_zones.available.names[0]

  partitions = [
    module.slurm_partition_0.partition,
  ]

  depends_on = [
    module.slurm_firewall_rules,
  ]
}

###################
# LOGIN: TEMPLATE #
###################

module "slurm_login_instance_template" {
  source = "../../../../modules/slurm_instance_template"

  name_prefix      = "${var.cluster_name}-login"
  project_id       = var.project_id
  slurm_cluster_id = module.slurm_controller_instance.slurm_cluster_id
  subnetwork       = module.network.network.subnets_self_links[0]
  tags             = [var.cluster_name]
}

###################
# LOGIN: INSTANCE #
###################

module "slurm_login" {
  source = "../../../../modules/slurm_login_instance"

  cluster_name      = var.cluster_name
  instance_template = module.slurm_login_instance_template.self_link
  region            = var.region
  slurm_cluster_id  = module.slurm_controller_instance.slurm_cluster_id
  subnetwork        = module.network.network.subnets_self_links[0]
  zone              = data.google_compute_zones.available.names[0]

  depends_on = [
    module.slurm_controller_instance,
  ]
}
