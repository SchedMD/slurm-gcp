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
  slurm_cluster_id = module.slurm_controller_hybrid.slurm_cluster_id
}

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
# COMPUTE: TEMPLATES #
######################

module "slurm_compute_instance_template" {
  source = "../../../modules/slurm_instance_template"

  for_each = { for x in var.compute_templates : x.alias => x }

  additional_disks         = each.value.additional_disks
  disable_smt              = each.value.disable_smt
  disk_labels              = each.value.disk_labels
  disk_size_gb             = each.value.disk_size_gb
  disk_type                = each.value.disk_type
  enable_confidential_vm   = each.value.enable_confidential_vm
  enable_shielded_vm       = each.value.enable_shielded_vm
  gpu                      = each.value.gpu
  labels                   = each.value.labels
  machine_type             = each.value.machine_type
  name_prefix              = "${var.cluster_name}-compute-${each.key}"
  preemptible              = each.value.preemptible
  project_id               = var.project_id
  service_account          = var.compute_service_account
  shielded_instance_config = each.value.shielded_instance_config
  slurm_cluster_id         = local.slurm_cluster_id
  source_image             = each.value.source_image
  source_image_family      = each.value.source_image_family
  source_image_project     = each.value.source_image_project
  subnetwork               = module.network.network.subnets_self_links[0]
  tags                     = each.value.tags
}

###################
# SLURM PARTITION #
###################

module "slurm_partition" {
  source = "../../../modules/slurm_partition"

  for_each = { for x in var.partitions : x.partition_name => x }

  partition_name = each.value.partition_name
  partition_conf = each.value.partition_conf
  partition_nodes = [for n in each.value.partition_nodes : {
    node_group_name   = n.node_group_name
    instance_template = module.slurm_compute_instance_template[n.compute_template_alias_ref].self_link
    count_static      = n.count_static
    count_dynamic     = n.count_dynamic
  }]
  subnetwork              = module.network.network.subnets_self_links[0]
  zone_policy_allow       = each.value.zone_policy_allow
  zone_policy_deny        = each.value.zone_policy_deny
  network_storage         = each.value.network_storage
  enable_job_exclusive    = each.value.enable_job_exclusive
  enable_placement_groups = each.value.enable_placement_groups
}

######################
# CONTROLLER: HYBRID #
######################

module "slurm_controller_hybrid" {
  source = "../../../modules/slurm_controller_hybrid"

  project_id = var.project_id

  cluster_name = var.cluster_name
  enable_devel = var.enable_devel

  munge_key = var.munge_key
  jwt_key   = var.jwt_key

  network_storage       = var.network_storage
  login_network_storage = var.login_network_storage

  compute_d = var.compute_d

  partitions = values(module.slurm_partition)[*].partition

  slurm_bin_dir = var.slurm_bin_dir
  slurm_log_dir = var.slurm_log_dir

  output_dir       = "./config"
  cloud_parameters = var.cloud_parameters

  depends_on = [
    module.slurm_firewall_rules,
  ]
}
