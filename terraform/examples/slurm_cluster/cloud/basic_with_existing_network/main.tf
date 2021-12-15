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
  network = data.google_compute_subnetwork.cluster_subnetwork.network

  subnetwork = data.google_compute_subnetwork.cluster_subnetwork.self_link

  subnetwork_project = data.google_compute_subnetwork.cluster_subnetwork.project
}

############
# PROVIDER #
############

provider "google" {
  project = var.project_id
}

########
# DATA #
########

data "google_compute_subnetwork" "cluster_subnetwork" {
  project = var.subnetwork_project
  name    = var.subnetwork
  region  = var.region
}

data "google_compute_zones" "available" {
  project = data.google_compute_subnetwork.cluster_subnetwork.project
  region  = data.google_compute_subnetwork.cluster_subnetwork.region
}

##################
# FIREWALL RULES #
##################

module "slurm_firewall_rules" {
  source = "../../../../modules/slurm_firewall_rules"

  project_id   = local.subnetwork_project
  network_name = local.network
  cluster_name = var.cluster_name
  target_tags  = [var.cluster_name]
}

#########################
# CONTROLLER: TEMPLATES #
#########################

module "slurm_controller_instance_template" {
  source = "../../../../modules/slurm_instance_template"

  name_prefix      = "${var.cluster_name}-controller"
  network          = var.project_id != local.subnetwork_project ? var.instance_template_network : local.network
  project_id       = var.project_id
  slurm_cluster_id = module.slurm_controller_instance.slurm_cluster_id
  tags             = [var.cluster_name]
}

######################
# COMPUTE: TEMPLATES #
######################

module "slurm_compute_instance_template" {
  source = "../../../../modules/slurm_instance_template"

  name_prefix      = "${var.cluster_name}-n1"
  network          = var.project_id != local.subnetwork_project ? var.instance_template_network : local.network
  project_id       = var.project_id
  slurm_cluster_id = module.slurm_controller_instance.slurm_cluster_id
  tags             = [var.cluster_name]
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
      instance_template = module.slurm_compute_instance_template.self_link
      count_static      = 0
      count_dynamic     = 20
    },
  ]
  subnetwork = local.subnetwork
}

########################
# CONTROLLER: INSTANCE #
########################

module "slurm_controller_instance" {
  source = "../../../../modules/slurm_controller_instance"

  cluster_name      = var.cluster_name
  instance_template = module.slurm_controller_instance_template.self_link
  subnetwork        = local.subnetwork
  zone              = data.google_compute_zones.available.names[0]

  partitions = [
    module.slurm_partition.partition,
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
  network          = var.project_id != local.subnetwork_project ? var.instance_template_network : local.network
  project_id       = var.project_id
  slurm_cluster_id = module.slurm_controller_instance.slurm_cluster_id
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
  subnetwork        = local.subnetwork
  zone              = data.google_compute_zones.available.names[0]

  depends_on = [
    module.slurm_controller_instance,
  ]
}
