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
  login_instances = {
    for t in var.login_instances
    : "${module.network.network.subnets_regions[0]}/${module.network.network.subnets_names[0]}"
    => t
  }

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

###################
# LOGIN: TEMPLATE #
###################

module "slurm_login_instance_templates" {
  source = "../../../modules/slurm_instance_template"

  for_each = var.login_templates

  project_id = var.project_id

  ### network ###
  subnetwork = module.network.network.subnets_self_links[0]
  tags       = concat([var.cluster_name], each.value.tags)

  ### instance ###
  name_prefix              = "${var.cluster_name}-login-${each.key}"
  service_account          = var.login_service_account
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
  slurm_cluster_id = module.slurm_controller_instance.slurm_cluster_id
  disable_smt      = each.value.disable_smt
}

###################
# LOGIN: INSTANCE #
###################

module "slurm_login_instances" {
  source = "../../../modules/slurm_login_instance"

  for_each = local.login_instances

  ### network ###
  subnetwork = module.network.network.subnets_self_links[0]

  ### instance ###
  instance_template = module.slurm_login_instance_templates[each.value.template].instance_template.self_link
  num_instances     = each.value.count

  ### slurm ###
  cluster_name     = module.slurm_controller_instance.cluster_name
  slurm_cluster_id = module.slurm_controller_instance.slurm_cluster_id

  depends_on = [
    # NOTE: changes to `module.slurm_controller_instance` will cause a
    # delta in `module.slurm_login_instances` force a replacement.
    module.slurm_controller_instance,
  ]
}

########################
# CONTROLLER: TEMPLATE #
########################

module "slurm_controller_instance_template" {
  source = "../../../modules/slurm_instance_template"

  project_id = var.project_id

  ### network ###
  subnetwork = module.network.network.subnets_self_links[0]
  tags       = concat([var.cluster_name], var.controller_template.tags)

  ### instance ###
  name_prefix              = "${var.cluster_name}-controller"
  service_account          = var.controller_service_account
  machine_type             = var.controller_template.machine_type
  min_cpu_platform         = var.controller_template.min_cpu_platform
  gpu                      = var.controller_template.gpu
  shielded_instance_config = var.controller_template.shielded_instance_config
  enable_confidential_vm   = var.controller_template.enable_confidential_vm
  enable_shielded_vm       = var.controller_template.enable_shielded_vm
  preemptible              = var.controller_template.preemptible
  labels                   = var.controller_template.labels

  ### source image ###
  source_image_project = var.controller_template.source_image_project
  source_image_family  = var.controller_template.source_image_family
  source_image         = var.controller_template.source_image

  ### disk ###
  disk_type        = var.controller_template.disk_type
  disk_size_gb     = var.controller_template.disk_size_gb
  disk_labels      = var.controller_template.disk_labels
  disk_auto_delete = var.controller_template.disk_auto_delete
  additional_disks = var.controller_template.additional_disks

  ### slurm ###
  slurm_cluster_id = module.slurm_controller_instance.slurm_cluster_id
  disable_smt      = var.controller_template.disable_smt
}

########################
# CONTROLLER: INSTANCE #
########################

module "slurm_controller_instance" {
  source = "../../../modules/slurm_controller_instance"

  ### network ###
  subnetwork = module.network.network.subnets_self_links[0]

  ### instance ###
  instance_template = module.slurm_controller_instance_template.instance_template.self_link

  ### slurm ###
  cluster_name = var.cluster_name
  enable_devel = var.enable_devel

  cloudsql = var.config.cloudsql

  munge_key = var.config.munge_key
  jwt_key   = var.config.jwt_key
  serf_keys = var.config.serf_keys

  network_storage       = var.config.network_storage
  login_network_storage = var.config.login_network_storage

  slurm_conf_tpl    = var.config.slurm_conf_tpl != null ? abspath(var.config.slurm_conf_tpl) : null
  slurmdbd_conf_tpl = var.config.slurmdbd_conf_tpl != null ? abspath(var.config.slurmdbd_conf_tpl) : null
  cgroup_conf_tpl   = var.config.cgroup_conf_tpl != null ? abspath(var.config.cgroup_conf_tpl) : null

  controller_d = var.config.controller_d != null ? abspath(var.config.controller_d) : null
  compute_d    = var.config.compute_d != null ? abspath(var.config.compute_d) : null

  template_map = local.template_map
  partitions   = local.partitions

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
  slurm_cluster_id = module.slurm_controller_instance.slurm_cluster_id
  disable_smt      = each.value.disable_smt
}
