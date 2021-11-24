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
  template_map = {
    for k, v in var.compute_templates
    : k => module.slurm_compute_instance_templates[k].instance_template.self_link
  }

  partitions = {
    for k, v in var.partitions : k => {
      conf             = v.conf
      exclusive        = v.exclusive
      network_storage  = v.network_storage
      nodes            = v.nodes
      placement_groups = v.placement_groups
      region           = module.network.network.subnets_regions[0]
      subnetwork       = module.network.network.subnets_self_links[0]
      zone_policy      = v.zone_policy
    }
  }
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
  source_tags  = [var.cluster_name]
}

######################
# CONTROLLER: HYBRID #
######################

module "slurm_controller_hybrid" {
  source = "../../../modules/slurm_controller_hybrid"

  project_id = var.project_id

  cluster_name = var.cluster_name
  enable_devel = var.enable_devel

  munge_key = var.config.munge_key
  jwt_key   = var.config.jwt_key
  serf_keys = var.config.serf_keys

  network_storage       = var.config.network_storage
  login_network_storage = var.config.login_network_storage

  compute_d = var.config.compute_d

  template_map = local.template_map
  partitions   = local.partitions

  slurm_bin_dir = var.config.slurm_bin_dir
  slurm_log_dir = var.config.slurm_log_dir

  output_dir       = "./config"
  cloud_parameters = var.config.cloud_parameters

  depends_on = [
    module.slurm_firewall_rules,
  ]
}

#####################
# COMPUTE: TEMPLATE #
#####################

module "slurm_compute_instance_templates" {
  source = "../../../modules/slurm_instance_template"

  for_each = var.compute_templates

  project_id = var.project_id

  ### network ###
  subnetwork = module.network.network.subnets_self_links[0]
  tags       = concat([var.cluster_name], each.value.tags)

  ### instance ###
  name_prefix              = "${var.cluster_name}-compute-${each.key}"
  service_account          = var.compute_service_account
  machine_type             = each.value.machine_type
  min_cpu_platform         = each.value.min_cpu_platform
  gpu                      = each.value.gpu
  shielded_instance_config = each.value.shielded_instance_config
  enable_confidential_vm   = each.value.enable_confidential_vm
  enable_shielded_vm       = each.value.enable_shielded_vm
  preemptible              = each.value.preemptible
  labels                   = each.value.labels

  ### source image ###
  source_image_project = each.value.source_image_project
  source_image_family  = each.value.source_image_family
  source_image         = each.value.source_image

  ### disk ###
  disk_type        = each.value.disk_type
  disk_size_gb     = each.value.disk_size_gb
  disk_labels      = each.value.disk_labels
  disk_auto_delete = each.value.disk_auto_delete
  additional_disks = each.value.additional_disks

  ### slurm ###
  cluster_id  = module.slurm_controller_hybrid.cluster_id
  disable_smt = each.value.disable_smt
}
