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
  slurm_cluster_id = random_uuid.slurm_cluster_id.result

  partition_map = { for x in var.partitions : x.partition_name => x }

  login_map = { for x in var.login_node_groups : x.group_name => x }
}

##########
# RANDOM #
##########

resource "random_uuid" "slurm_cluster_id" {
}

###################
# SLURM PARTITION #
###################

module "slurm_partition" {
  source = "../slurm_partition"

  for_each = local.partition_map

  cluster_name                 = var.cluster_name
  compute_node_groups          = each.value.compute_node_groups
  compute_node_groups_defaults = var.compute_node_groups_defaults
  enable_job_exclusive         = lookup(each.value, "enable_job_exclusive", false)
  enable_placement_groups      = lookup(each.value, "enable_placement_groups", false)
  network_storage              = lookup(each.value, "network_storage", [])
  partition_name               = each.value.partition_name
  partition_conf               = lookup(each.value, "partition_conf", {})
  project_id                   = var.project_id
  region                       = lookup(each.value, "region", null)
  subnetwork_project           = lookup(each.value, "subnetwork_project", null)
  subnetwork                   = each.value.subnetwork
  zone_policy_allow            = lookup(each.value, "zone_policy_allow", [])
  zone_policy_deny             = lookup(each.value, "zone_policy_deny", [])
}

########################
# CONTROLLER: TEMPLATE #
########################

module "slurm_controller_template" {
  source = "../slurm_controller_template"

  count = var.enable_hybrid ? 0 : 1

  additional_disks         = lookup(var.controller_instance_config, "additional_disks", [])
  can_ip_forward           = lookup(var.controller_instance_config, "can_ip_forward", null)
  cluster_name             = var.cluster_name
  disable_smt              = lookup(var.controller_instance_config, "disable_smt", false)
  disk_auto_delete         = lookup(var.controller_instance_config, "disk_auto_delete", true)
  disk_labels              = lookup(var.controller_instance_config, "disk_labels", {})
  disk_size_gb             = lookup(var.controller_instance_config, "disk_size_gb", null)
  disk_type                = lookup(var.controller_instance_config, "disk_type", null)
  enable_confidential_vm   = lookup(var.controller_instance_config, "enable_confidential_vm", false)
  enable_oslogin           = var.enable_oslogin
  enable_shielded_vm       = lookup(var.controller_instance_config, "enable_shielded_vm", false)
  gpu                      = lookup(var.controller_instance_config, "gpu", null)
  machine_type             = lookup(var.controller_instance_config, "machine_type", "n1-standard-1")
  min_cpu_platform         = lookup(var.controller_instance_config, "min_cpu_platform", null)
  network_ip               = lookup(var.controller_instance_config, "network_ip", "")
  network                  = lookup(var.controller_instance_config, "network", null)
  on_host_maintenance      = lookup(var.controller_instance_config, "on_host_maintenance", null)
  preemptible              = lookup(var.controller_instance_config, "preemptible", false)
  project_id               = var.project_id
  region                   = lookup(var.controller_instance_config, "region", null)
  service_account          = lookup(var.controller_instance_config, "service_account", null)
  shielded_instance_config = lookup(var.controller_instance_config, "shielded_instance_config", null)
  slurm_cluster_id         = local.slurm_cluster_id
  source_image_family      = lookup(var.controller_instance_config, "source_image_family", "")
  source_image_project     = lookup(var.controller_instance_config, "source_image_project", "")
  source_image             = lookup(var.controller_instance_config, "source_image", "")
  subnetwork_project       = lookup(var.controller_instance_config, "subnetwork_project", null)
  subnetwork               = lookup(var.controller_instance_config, "subnetwork", "default")
  tags                     = concat([var.cluster_name], lookup(var.controller_instance_config, "tags", []))
}

########################
# CONTROLLER: INSTANCE #
########################

module "slurm_controller_instance" {
  source = "../slurm_controller_instance"

  count = var.enable_hybrid ? 0 : 1

  access_config     = lookup(var.controller_instance_config, "access_config", [])
  cluster_name      = var.cluster_name
  instance_template = module.slurm_controller_template[0].self_link
  region            = lookup(var.controller_instance_config, "region", null)
  slurm_cluster_id  = local.slurm_cluster_id
  static_ips        = lookup(var.controller_instance_config, "static_ips", [])
  subnetwork        = lookup(var.controller_instance_config, "subnetwork", "default")
  zone              = lookup(var.controller_instance_config, "zone", null)

  cgroup_conf_tpl       = var.cgroup_conf_tpl
  cloud_parameters      = var.cloud_parameters
  cloudsql              = var.cloudsql
  controller_d          = var.controller_d
  compute_d             = var.compute_d
  enable_devel          = var.enable_devel
  jwt_key               = var.jwt_key
  login_network_storage = var.login_network_storage
  munge_key             = var.munge_key
  network_storage       = var.network_storage
  partitions            = values(module.slurm_partition)[*].partition
  slurmdbd_conf_tpl     = var.slurmdbd_conf_tpl
  slurm_conf_tpl        = var.slurm_conf_tpl
}

######################
# CONTROLLER: HYBRID #
######################

module "slurm_controller_hybrid" {
  source = "../slurm_controller_hybrid"

  count = var.enable_hybrid ? 1 : 0

  cluster_name     = var.cluster_name
  project_id       = var.project_id
  slurm_cluster_id = local.slurm_cluster_id

  google_app_cred_path = lookup(var.controller_hybrid_config, "google_app_cred_path", null)
  slurm_scripts_dir    = lookup(var.controller_hybrid_config, "slurm_scripts_dir", null)
  slurm_bin_dir        = lookup(var.controller_hybrid_config, "slurm_bin_dir", null)
  slurm_log_dir        = lookup(var.controller_hybrid_config, "slurm_log_dir", "/var/log/slurm")
  output_dir           = lookup(var.controller_hybrid_config, "output_dir", ".")
  cloud_parameters     = var.cloud_parameters
  compute_d            = var.compute_d
  jwt_key              = var.jwt_key
  munge_key            = var.munge_key
  partitions           = values(module.slurm_partition)[*].partition
}

###################
# LOGIN: TEMPLATE #
###################

module "slurm_login_template" {
  source = "../slurm_login_template"

  for_each = local.login_map

  additional_disks         = lookup(each.value, "additional_disks", [])
  can_ip_forward           = lookup(each.value, "can_ip_forward", null)
  cluster_name             = var.cluster_name
  disable_smt              = lookup(each.value, "disable_smt", false)
  disk_auto_delete         = lookup(each.value, "disk_auto_delete", true)
  disk_labels              = lookup(each.value, "disk_labels", {})
  disk_size_gb             = lookup(each.value, "disk_size_gb", null)
  disk_type                = lookup(each.value, "disk_type", null)
  enable_confidential_vm   = lookup(each.value, "enable_confidential_vm", false)
  enable_oslogin           = var.enable_oslogin
  enable_shielded_vm       = lookup(each.value, "enable_shielded_vm", false)
  gpu                      = lookup(each.value, "gpu", null)
  machine_type             = lookup(each.value, "machine_type", "n1-standard-1")
  min_cpu_platform         = lookup(each.value, "min_cpu_platform", null)
  network_ip               = lookup(each.value, "network_ip", "")
  network                  = lookup(each.value, "network", null)
  on_host_maintenance      = lookup(each.value, "on_host_maintenance", null)
  preemptible              = lookup(each.value, "preemptible", false)
  project_id               = var.project_id
  region                   = lookup(each.value, "region", null)
  service_account          = lookup(each.value, "service_account", null)
  shielded_instance_config = lookup(each.value, "shielded_instance_config", null)
  slurm_cluster_id         = local.slurm_cluster_id
  source_image_family      = lookup(each.value, "source_image_family", "")
  source_image_project     = lookup(each.value, "source_image_project", "")
  source_image             = lookup(each.value, "source_image", "")
  subnetwork_project       = lookup(each.value, "subnetwork_project", null)
  subnetwork               = lookup(each.value, "subnetwork", "default")
  tags                     = concat([var.cluster_name], lookup(each.value, "tags", []))
}

###################
# LOGIN: TEMPLATE #
###################

module "slurm_login_instance" {
  source = "../slurm_login_instance"

  for_each = local.login_map

  access_config     = lookup(each.value, "access_config", [])
  cluster_name      = var.cluster_name
  instance_template = module.slurm_login_template[each.value.group_name].self_link
  num_instances     = lookup(each.value, "num_instances", 1)
  region            = lookup(each.value, "region", null)
  static_ips        = lookup(each.value, "static_ips", [])
  subnetwork        = lookup(each.value, "subnetwork", "default")
  zone              = lookup(each.value, "zone", null)

  depends_on = [
    # Ensure Controller is up before attempting to mount file systems from it
    module.slurm_controller_instance,
  ]
}
