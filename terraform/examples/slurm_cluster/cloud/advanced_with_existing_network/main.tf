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
  login_map = { for x in var.login : x.alias => x }

  slurm_cluster_id = module.slurm_controller_instance.slurm_cluster_id

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
  network_name = data.google_compute_subnetwork.cluster_subnetwork.network
  cluster_name = var.cluster_name
  target_tags  = [var.cluster_name]
}

#########################
# CONTROLLER: TEMPLATES #
#########################

module "slurm_controller_template" {
  source = "../../../../modules/slurm_controller_template"

  additional_disks         = var.controller_template.additional_disks
  cluster_name             = var.cluster_name
  disable_smt              = var.controller_template.disable_smt
  disk_labels              = var.controller_template.disk_labels
  disk_size_gb             = var.controller_template.disk_size_gb
  disk_type                = var.controller_template.disk_type
  enable_confidential_vm   = var.controller_template.enable_confidential_vm
  enable_shielded_vm       = var.controller_template.enable_shielded_vm
  gpu                      = var.controller_template.gpu
  labels                   = var.controller_template.labels
  machine_type             = var.controller_template.machine_type
  name_prefix              = "${var.cluster_name}-controller"
  network                  = var.project_id != local.subnetwork_project ? var.instance_template_network : local.network
  preemptible              = var.controller_template.preemptible
  project_id               = var.project_id
  service_account          = var.controller_service_account
  shielded_instance_config = var.controller_template.shielded_instance_config
  slurm_cluster_id         = local.slurm_cluster_id
  source_image             = var.controller_template.source_image
  source_image_family      = var.controller_template.source_image_family
  source_image_project     = var.controller_template.source_image_project
  tags                     = concat([var.cluster_name], var.controller_template.tags)
}

######################
# COMPUTE: TEMPLATES #
######################

module "slurm_compute_template" {
  source = "../../../../modules/slurm_compute_template"

  for_each = { for x in var.compute_templates : x.alias => x }

  additional_disks         = each.value.additional_disks
  cluster_name             = var.cluster_name
  disable_smt              = each.value.disable_smt
  disk_labels              = each.value.disk_labels
  disk_size_gb             = each.value.disk_size_gb
  disk_type                = each.value.disk_type
  enable_confidential_vm   = each.value.enable_confidential_vm
  enable_shielded_vm       = each.value.enable_shielded_vm
  gpu                      = each.value.gpu
  labels                   = each.value.labels
  machine_type             = each.value.machine_type
  name_prefix              = each.value.alias
  network                  = var.project_id != local.subnetwork_project ? var.instance_template_network : local.network
  preemptible              = each.value.preemptible
  project_id               = var.project_id
  service_account          = var.compute_service_account
  shielded_instance_config = each.value.shielded_instance_config
  slurm_cluster_id         = local.slurm_cluster_id
  source_image             = each.value.source_image
  source_image_family      = each.value.source_image_family
  source_image_project     = each.value.source_image_project
  tags                     = concat([var.cluster_name], each.value.tags)
}

###################
# SLURM PARTITION #
###################

module "slurm_partition" {
  source = "../../../../modules/slurm_partition"

  for_each = { for x in var.partitions : x.partition_name => x }

  partition_name = each.value.partition_name
  partition_conf = each.value.partition_conf
  partition_nodes = [for n in each.value.partition_nodes : {
    node_group_name   = n.node_group_name
    instance_template = module.slurm_compute_template[n.compute_template_alias_ref].self_link
    count_static      = n.count_static
    count_dynamic     = n.count_dynamic
  }]
  subnetwork              = local.subnetwork
  zone_policy_allow       = each.value.zone_policy_allow
  zone_policy_deny        = each.value.zone_policy_deny
  network_storage         = each.value.network_storage
  enable_job_exclusive    = each.value.enable_job_exclusive
  enable_placement_groups = each.value.enable_placement_groups
}

########################
# CONTROLLER: INSTANCE #
########################

module "slurm_controller_instance" {
  source = "../../../../modules/slurm_controller_instance"

  cgroup_conf_tpl       = var.cgroup_conf_tpl
  cloud_parameters      = var.cloud_parameters
  cloudsql              = var.cloudsql
  cluster_name          = var.cluster_name
  controller_d          = var.controller_d
  compute_d             = var.compute_d
  enable_devel          = var.enable_devel
  instance_template     = module.slurm_controller_template.self_link
  jwt_key               = var.jwt_key
  login_network_storage = var.login_network_storage
  munge_key             = var.munge_key
  network_storage       = var.network_storage
  slurmdbd_conf_tpl     = var.slurmdbd_conf_tpl
  slurm_conf_tpl        = var.slurm_conf_tpl
  subnetwork            = local.subnetwork
  zone                  = data.google_compute_zones.available.names[0]

  partitions = values(module.slurm_partition)[*].partition

  depends_on = [
    module.slurm_firewall_rules,
  ]
}

###################
# LOGIN: TEMPLATE #
###################

module "slurm_login_template" {
  source = "../../../../modules/slurm_login_template"

  for_each = local.login_map

  additional_disks         = each.value.additional_disks
  cluster_name             = var.cluster_name
  disable_smt              = each.value.disable_smt
  disk_labels              = each.value.disk_labels
  disk_size_gb             = each.value.disk_size_gb
  disk_type                = each.value.disk_type
  enable_confidential_vm   = each.value.enable_confidential_vm
  enable_shielded_vm       = each.value.enable_shielded_vm
  gpu                      = each.value.gpu
  labels                   = each.value.labels
  machine_type             = each.value.machine_type
  name_prefix              = each.value.alias
  network                  = var.project_id != local.subnetwork_project ? var.instance_template_network : local.network
  preemptible              = each.value.preemptible
  project_id               = var.project_id
  service_account          = var.login_service_account
  shielded_instance_config = each.value.shielded_instance_config
  slurm_cluster_id         = local.slurm_cluster_id
  source_image             = each.value.source_image
  source_image_family      = each.value.source_image_family
  source_image_project     = each.value.source_image_project
  tags                     = concat([var.cluster_name], each.value.tags)
}

###################
# LOGIN: INSTANCE #
###################

module "slurm_login_instance" {
  source = "../../../../modules/slurm_login_instance"

  for_each = local.login_map

  cluster_name      = var.cluster_name
  instance_template = module.slurm_login_template[each.value.alias].self_link
  num_instances     = each.value.num_instances
  subnetwork        = local.subnetwork
  zone              = data.google_compute_zones.available.names[0]

  depends_on = [
    # Must be created after the controller to mount NFS
    module.slurm_controller_instance,
  ]
}
