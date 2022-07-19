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
  partition_map = { for x in var.partitions : x.partition_name => x }

  have_template = (
    var.controller_instance_config.instance_template != null
    && var.controller_instance_config.instance_template != ""
    ? true
    : false
  )
}

###################
# SLURM PARTITION #
###################

module "slurm_partition" {
  source = "./modules/slurm_partition"

  for_each = local.partition_map

  partition_nodes           = each.value.partition_nodes
  enable_job_exclusive      = each.value.enable_job_exclusive
  enable_reconfigure        = var.enable_reconfigure
  enable_placement_groups   = each.value.enable_placement_groups
  network_storage           = each.value.network_storage
  partition_name            = each.value.partition_name
  partition_conf            = each.value.partition_conf
  partition_startup_scripts = each.value.partition_startup_scripts
  project_id                = var.project_id
  region                    = each.value.region
  slurm_cluster_name        = var.slurm_cluster_name
  subnetwork_project        = each.value.subnetwork_project
  subnetwork                = each.value.subnetwork
  zone_policy_allow         = each.value.zone_policy_allow
  zone_policy_deny          = each.value.zone_policy_deny
}

########################
# CONTROLLER: TEMPLATE #
########################

module "slurm_controller_template" {
  source = "./modules/slurm_instance_template"

  count = var.enable_hybrid || local.have_template ? 0 : 1

  additional_disks         = var.controller_instance_config.additional_disks
  can_ip_forward           = var.controller_instance_config.can_ip_forward
  disable_smt              = var.controller_instance_config.disable_smt
  disk_auto_delete         = var.controller_instance_config.disk_auto_delete
  disk_labels              = var.controller_instance_config.disk_labels
  disk_size_gb             = var.controller_instance_config.disk_size_gb
  disk_type                = var.controller_instance_config.disk_type
  enable_confidential_vm   = var.controller_instance_config.enable_confidential_vm
  enable_oslogin           = var.controller_instance_config.enable_oslogin
  enable_shielded_vm       = var.controller_instance_config.enable_shielded_vm
  gpu                      = var.controller_instance_config.gpu
  labels                   = var.controller_instance_config.labels
  machine_type             = var.controller_instance_config.machine_type
  metadata                 = var.controller_instance_config.metadata
  min_cpu_platform         = var.controller_instance_config.min_cpu_platform
  network_ip               = var.controller_instance_config.network_ip != null ? var.controller_instance_config.network_ip : ""
  on_host_maintenance      = var.controller_instance_config.on_host_maintenance
  preemptible              = var.controller_instance_config.preemptible
  project_id               = var.project_id
  region                   = var.controller_instance_config.region
  service_account          = var.controller_instance_config.service_account
  shielded_instance_config = var.controller_instance_config.shielded_instance_config
  slurm_cluster_name       = var.slurm_cluster_name
  slurm_instance_role      = "controller"
  source_image_family      = var.controller_instance_config.source_image_family
  source_image_project     = var.controller_instance_config.source_image_project
  source_image             = var.controller_instance_config.source_image
  subnetwork_project       = var.controller_instance_config.subnetwork_project
  subnetwork               = var.controller_instance_config.subnetwork
  tags                     = concat([var.slurm_cluster_name], var.controller_instance_config.tags)
}

########################
# CONTROLLER: INSTANCE #
########################

module "slurm_controller_instance" {
  source = "./modules/slurm_controller_instance"

  count = var.enable_hybrid ? 0 : 1

  access_config      = var.controller_instance_config.access_config
  instance_template  = local.have_template ? var.controller_instance_config.instance_template : module.slurm_controller_template[0].self_link
  project_id         = var.project_id
  region             = var.controller_instance_config.region
  slurm_cluster_name = var.slurm_cluster_name
  static_ips         = var.controller_instance_config.static_ip != null ? [var.controller_instance_config.static_ip] : []
  subnetwork         = var.controller_instance_config.subnetwork
  zone               = var.controller_instance_config.zone

  cgroup_conf_tpl              = var.cgroup_conf_tpl
  cloud_parameters             = var.cloud_parameters
  cloudsql                     = var.cloudsql
  controller_startup_scripts   = var.controller_startup_scripts
  compute_startup_scripts      = var.compute_startup_scripts
  enable_devel                 = var.enable_devel
  enable_bigquery_load         = var.enable_bigquery_load
  enable_cleanup_compute       = var.enable_cleanup_compute
  enable_cleanup_subscriptions = var.enable_cleanup_subscriptions
  enable_reconfigure           = var.enable_reconfigure
  epilog_scripts               = var.epilog_scripts
  login_network_storage        = var.login_network_storage
  disable_default_mounts       = var.disable_default_mounts
  network_storage              = var.network_storage
  partitions                   = values(module.slurm_partition)[*]
  prolog_scripts               = var.prolog_scripts
  slurmdbd_conf_tpl            = var.slurmdbd_conf_tpl
  slurm_conf_tpl               = var.slurm_conf_tpl
}

######################
# CONTROLLER: HYBRID #
######################

module "slurm_controller_hybrid" {
  source = "./modules/slurm_controller_hybrid"

  count = var.enable_hybrid ? 1 : 0

  project_id         = var.project_id
  slurm_cluster_name = var.slurm_cluster_name

  google_app_cred_path         = var.controller_hybrid_config.google_app_cred_path
  slurm_control_host           = var.controller_hybrid_config.slurm_control_host
  slurm_bin_dir                = var.controller_hybrid_config.slurm_bin_dir
  slurm_log_dir                = var.controller_hybrid_config.slurm_log_dir
  output_dir                   = var.controller_hybrid_config.output_dir
  cloud_parameters             = var.cloud_parameters
  compute_startup_scripts      = var.compute_startup_scripts
  enable_devel                 = var.enable_devel
  enable_bigquery_load         = var.enable_bigquery_load
  enable_cleanup_compute       = var.enable_cleanup_compute
  enable_cleanup_subscriptions = var.enable_cleanup_subscriptions
  enable_reconfigure           = var.enable_reconfigure
  epilog_scripts               = var.epilog_scripts
  partitions                   = values(module.slurm_partition)[*]
  prolog_scripts               = var.prolog_scripts
}

###################
# LOGIN: TEMPLATE #
###################

module "slurm_login_template" {
  source = "./modules/slurm_instance_template"

  for_each = {
    for x in var.login_nodes : x.group_name => x
    if(x.instance_template == null || x.instance_template == "")
  }

  additional_disks         = each.value.additional_disks
  can_ip_forward           = each.value.can_ip_forward
  disable_smt              = each.value.disable_smt
  disk_auto_delete         = each.value.disk_auto_delete
  disk_labels              = each.value.disk_labels
  disk_size_gb             = each.value.disk_size_gb
  disk_type                = each.value.disk_type
  enable_confidential_vm   = each.value.enable_confidential_vm
  enable_oslogin           = each.value.enable_oslogin
  enable_shielded_vm       = each.value.enable_shielded_vm
  gpu                      = each.value.gpu
  labels                   = each.value.labels
  machine_type             = each.value.machine_type
  metadata                 = each.value.metadata
  min_cpu_platform         = each.value.min_cpu_platform
  on_host_maintenance      = each.value.on_host_maintenance
  preemptible              = each.value.preemptible
  project_id               = var.project_id
  region                   = each.value.region
  service_account          = each.value.service_account
  shielded_instance_config = each.value.shielded_instance_config
  slurm_cluster_name       = var.slurm_cluster_name
  slurm_instance_role      = "login"
  source_image_family      = each.value.source_image_family
  source_image_project     = each.value.source_image_project
  source_image             = each.value.source_image
  subnetwork_project       = each.value.subnetwork_project
  subnetwork               = each.value.subnetwork
  tags                     = concat([var.slurm_cluster_name], each.value.tags)
}

###################
# LOGIN: INSTANCE #
###################

module "slurm_login_instance" {
  source = "./modules/slurm_login_instance"

  for_each = { for x in var.login_nodes : x.group_name => x }

  access_config = lookup(each.value, "access_config", [])
  instance_template = (
    each.value.instance_template != null && each.value.instance_template != ""
    ? each.value.instance_template
    : module.slurm_login_template[each.key].self_link
  )
  login_startup_scripts = var.login_startup_scripts
  num_instances         = each.value.num_instances
  project_id            = var.project_id
  region                = each.value.region
  slurm_cluster_name    = var.slurm_cluster_name
  static_ips            = each.value.static_ips
  subnetwork            = each.value.subnetwork
  zone                  = each.value.zone

  slurm_depends_on = flatten([
    # Ensure Controller is up before attempting to mount file systems from it
    module.slurm_controller_instance[0].slurm_controller_instances[*].instance_id,
  ])
}
