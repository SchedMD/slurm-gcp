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
  compute_node_groups_defaults = local.compute_node_groups_defaults
  enable_job_exclusive         = lookup(each.value, "enable_job_exclusive", false)
  enable_placement_groups      = lookup(each.value, "enable_placement_groups", false)
  network_storage              = lookup(each.value, "network_storage", [])
  partition_name               = each.value.partition_name
  partition_conf               = lookup(each.value, "partition_conf", {})
  partition_d                  = lookup(each.value, "partition_d", [])
  project_id                   = var.project_id
  region                       = lookup(each.value, "region", null)
  slurm_cluster_id             = local.slurm_cluster_id
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

  additional_disks         = lookup(var.controller_instance_config, "additional_disks", local.controller_instance_config["additional_disks"])
  can_ip_forward           = lookup(var.controller_instance_config, "can_ip_forward", local.controller_instance_config["can_ip_forward"])
  cluster_name             = var.cluster_name
  disable_smt              = lookup(var.controller_instance_config, "disable_smt", local.controller_instance_config["disable_smt"])
  disk_auto_delete         = lookup(var.controller_instance_config, "disk_auto_delete", local.controller_instance_config["disk_auto_delete"])
  disk_labels              = lookup(var.controller_instance_config, "disk_labels", local.controller_instance_config["disk_labels"])
  disk_size_gb             = lookup(var.controller_instance_config, "disk_size_gb", local.controller_instance_config["disk_size_gb"])
  disk_type                = lookup(var.controller_instance_config, "disk_type", local.controller_instance_config["disk_type"])
  enable_confidential_vm   = lookup(var.controller_instance_config, "enable_confidential_vm", local.controller_instance_config["enable_confidential_vm"])
  enable_oslogin           = lookup(var.controller_instance_config, "enable_oslogin", local.controller_instance_config["enable_oslogin"])
  enable_shielded_vm       = lookup(var.controller_instance_config, "enable_shielded_vm", local.controller_instance_config["enable_shielded_vm"])
  gpu                      = lookup(var.controller_instance_config, "gpu", local.controller_instance_config["gpu"])
  labels                   = lookup(var.controller_instance_config, "labels", local.controller_instance_config["labels"])
  machine_type             = lookup(var.controller_instance_config, "machine_type", local.controller_instance_config["machine_type"])
  metadata                 = lookup(var.controller_instance_config, "metadata", local.controller_instance_config["metadata"])
  min_cpu_platform         = lookup(var.controller_instance_config, "min_cpu_platform", local.controller_instance_config["min_cpu_platform"])
  network_ip               = lookup(var.controller_instance_config, "network_ip", local.controller_instance_config["network_ip"])
  network                  = lookup(var.controller_instance_config, "network", local.controller_instance_config["network"])
  on_host_maintenance      = lookup(var.controller_instance_config, "on_host_maintenance", local.controller_instance_config["on_host_maintenance"])
  preemptible              = lookup(var.controller_instance_config, "preemptible", local.controller_instance_config["preemptible"])
  project_id               = var.project_id
  region                   = lookup(var.controller_instance_config, "region", local.controller_instance_config["region"])
  service_account          = lookup(var.controller_instance_config, "service_account", local.controller_instance_config["service_account"])
  shielded_instance_config = lookup(var.controller_instance_config, "shielded_instance_config", local.controller_instance_config["shielded_instance_config"])
  slurm_cluster_id         = local.slurm_cluster_id
  source_image_family      = lookup(var.controller_instance_config, "source_image_family", local.controller_instance_config["source_image_family"])
  source_image_project     = lookup(var.controller_instance_config, "source_image_project", local.controller_instance_config["source_image_project"])
  source_image             = lookup(var.controller_instance_config, "source_image", local.controller_instance_config["source_image"])
  subnetwork_project       = lookup(var.controller_instance_config, "subnetwork_project", local.controller_instance_config["subnetwork_project"])
  subnetwork               = lookup(var.controller_instance_config, "subnetwork", local.controller_instance_config["subnetwork"])
  tags                     = concat([var.cluster_name], lookup(var.controller_instance_config, "tags", local.controller_instance_config["tags"]))
}

########################
# CONTROLLER: INSTANCE #
########################

module "slurm_controller_instance" {
  source = "../slurm_controller_instance"

  count = var.enable_hybrid ? 0 : 1

  access_config     = lookup(local.controller_instance_config, "access_config", [])
  cluster_name      = var.cluster_name
  instance_template = module.slurm_controller_template[0].self_link
  region            = lookup(local.controller_instance_config, "region", local.controller_instance_config["region"])
  slurm_cluster_id  = local.slurm_cluster_id
  static_ips        = lookup(local.controller_instance_config, "static_ips", [])
  subnetwork        = lookup(local.controller_instance_config, "subnetwork", local.controller_instance_config["subnetwork"])
  zone              = lookup(local.controller_instance_config, "zone", local.controller_instance_config["zone"])

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
  slurm_bin_dir        = lookup(var.controller_hybrid_config, "slurm_bin_dir", "/usr/local/bin")
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

  additional_disks         = lookup(each.value, "additional_disks", local.login_node_groups_defaults["additional_disks"])
  can_ip_forward           = lookup(each.value, "can_ip_forward", local.login_node_groups_defaults["can_ip_forward"])
  cluster_name             = var.cluster_name
  disable_smt              = lookup(each.value, "disable_smt", local.login_node_groups_defaults["disable_smt"])
  disk_auto_delete         = lookup(each.value, "disk_auto_delete", local.login_node_groups_defaults["disk_auto_delete"])
  disk_labels              = lookup(each.value, "disk_labels", local.login_node_groups_defaults["disk_labels"])
  disk_size_gb             = lookup(each.value, "disk_size_gb", local.login_node_groups_defaults["disk_size_gb"])
  disk_type                = lookup(each.value, "disk_type", local.login_node_groups_defaults["disk_type"])
  enable_confidential_vm   = lookup(each.value, "enable_confidential_vm", local.login_node_groups_defaults["enable_confidential_vm"])
  enable_oslogin           = lookup(each.value, "enable_oslogin", local.login_node_groups_defaults["enable_oslogin"])
  enable_shielded_vm       = lookup(each.value, "enable_shielded_vm", local.login_node_groups_defaults["enable_shielded_vm"])
  gpu                      = lookup(each.value, "gpu", local.login_node_groups_defaults["gpu"])
  labels                   = lookup(each.value, "labels", local.login_node_groups_defaults["labels"])
  machine_type             = lookup(each.value, "machine_type", local.login_node_groups_defaults["machine_type"])
  metadata                 = lookup(each.value, "metadata", local.login_node_groups_defaults["metadata"])
  min_cpu_platform         = lookup(each.value, "min_cpu_platform", local.login_node_groups_defaults["min_cpu_platform"])
  network_ip               = lookup(each.value, "network_ip", local.login_node_groups_defaults["network_ip"])
  network                  = lookup(each.value, "network", local.login_node_groups_defaults["network"])
  on_host_maintenance      = lookup(each.value, "on_host_maintenance", local.login_node_groups_defaults["on_host_maintenance"])
  preemptible              = lookup(each.value, "preemptible", local.login_node_groups_defaults["preemptible"])
  project_id               = var.project_id
  region                   = lookup(each.value, "region", local.login_node_groups_defaults["region"])
  service_account          = lookup(each.value, "service_account", local.login_node_groups_defaults["service_account"])
  shielded_instance_config = lookup(each.value, "shielded_instance_config", local.login_node_groups_defaults["shielded_instance_config"])
  slurm_cluster_id         = local.slurm_cluster_id
  source_image_family      = lookup(each.value, "source_image_family", local.login_node_groups_defaults["source_image_family"])
  source_image_project     = lookup(each.value, "source_image_project", local.login_node_groups_defaults["source_image_project"])
  source_image             = lookup(each.value, "source_image", local.login_node_groups_defaults["source_image"])
  subnetwork_project       = lookup(each.value, "subnetwork_project", local.login_node_groups_defaults["subnetwork_project"])
  subnetwork               = lookup(each.value, "subnetwork", local.login_node_groups_defaults["subnetwork"])
  tags                     = concat([var.cluster_name], lookup(each.value, "tags", local.login_node_groups_defaults["tags"]))
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
  region            = lookup(each.value, "region", local.login_node_groups_defaults["region"])
  static_ips        = lookup(each.value, "static_ips", [])
  subnetwork        = lookup(each.value, "subnetwork", local.login_node_groups_defaults["subnetwork"])
  zone              = lookup(each.value, "zone", local.login_node_groups_defaults["zone"])

  depends_on = [
    # Ensure Controller is up before attempting to mount file systems from it
    module.slurm_controller_instance,
  ]
}
