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
  nodeset_map = { for x in var.nodeset : x.nodeset_name => x }

  nodeset_dyn_map = { for x in var.nodeset_dyn : x.nodeset_name => x }

  nodeset_tpu_map = { for x in var.nodeset_tpu : x.nodeset_name => x }

  partition_map = { for x in var.partitions : x.partition_name => x }

  have_template = (
    var.controller_instance_config.instance_template != null
    && var.controller_instance_config.instance_template != ""
    ? true
    : false
  )
}

##########
# BUCKET #
##########

locals {
  controller_sa  = toset(flatten([for x in module.slurm_controller_template : x.service_account]))
  compute_sa     = toset(flatten([for x in module.slurm_nodeset_template : x.service_account]))
  compute_tpu_sa = toset(flatten([for x in module.slurm_nodeset_tpu : x.service_account]))
  login_sa       = toset(flatten([for x in module.slurm_login_template : x.service_account]))

  viewers = toset(flatten([
    formatlist("serviceAccount:%s", [for x in local.controller_sa : x.email]),
    formatlist("serviceAccount:%s", [for x in local.compute_sa : x.email]),
    formatlist("serviceAccount:%s", [for x in local.compute_tpu_sa : x.email]),
    formatlist("serviceAccount:%s", [for x in local.login_sa : x.email]),
  ]))
}

module "bucket" {
  source  = "terraform-google-modules/cloud-storage/google"
  version = "~> 3.0"

  count = var.create_bucket ? 1 : 0

  location   = var.region
  names      = [var.slurm_cluster_name]
  prefix     = "slurm"
  project_id = var.project_id

  force_destroy = {
    (var.slurm_cluster_name) = true
  }

  labels = {
    slurm_cluster_name = var.slurm_cluster_name
  }
}

resource "google_storage_bucket_iam_binding" "viewers" {
  bucket  = var.create_bucket ? module.bucket[0].name : var.bucket_name
  role    = "roles/storage.objectViewer"
  members = compact(local.viewers)
}

resource "google_storage_bucket_iam_binding" "legacyReaders" {
  bucket  = var.create_bucket ? module.bucket[0].name : var.bucket_name
  role    = "roles/storage.legacyBucketReader"
  members = compact(local.viewers)
}

###############
# SLURM FILES #
###############

module "slurm_files" {
  source = "./modules/slurm_files"

  bucket_dir                         = var.bucket_dir
  bucket_name                        = var.create_bucket ? module.bucket[0].name : var.bucket_name
  cgroup_conf_tpl                    = var.cgroup_conf_tpl
  cloud_parameters                   = var.cloud_parameters
  cloudsql_secret                    = try(module.slurm_controller_instance[0].cloudsql_secret, null)
  controller_startup_scripts         = var.controller_startup_scripts
  controller_startup_scripts_timeout = var.controller_startup_scripts_timeout
  compute_startup_scripts            = var.compute_startup_scripts
  compute_startup_scripts_timeout    = var.compute_startup_scripts_timeout
  enable_devel                       = var.enable_devel
  enable_debug_logging               = var.enable_debug_logging
  extra_logging_flags                = var.extra_logging_flags
  enable_hybrid                      = var.enable_hybrid
  enable_slurm_gcp_plugins           = var.enable_slurm_gcp_plugins
  enable_bigquery_load               = var.enable_bigquery_load
  epilog_scripts                     = var.epilog_scripts
  login_network_storage              = var.login_network_storage
  login_startup_scripts              = var.login_startup_scripts
  login_startup_scripts_timeout      = var.login_startup_scripts_timeout
  disable_default_mounts             = var.disable_default_mounts
  network_storage                    = var.network_storage
  partitions                         = values(module.slurm_partition)[*]
  nodeset                            = values(module.slurm_nodeset)[*]
  nodeset_dyn                        = values(module.slurm_nodeset_dyn)[*]
  nodeset_tpu                        = values(module.slurm_nodeset_tpu)[*]
  project_id                         = var.project_id
  prolog_scripts                     = var.prolog_scripts
  slurmdbd_conf_tpl                  = var.slurmdbd_conf_tpl
  slurm_conf_tpl                     = var.slurm_conf_tpl
  slurm_cluster_name                 = var.slurm_cluster_name
  # hybrid
  google_app_cred_path    = lookup(var.controller_hybrid_config, "google_app_cred_path", null)
  slurm_control_host      = lookup(var.controller_hybrid_config, "slurm_control_host", null)
  slurm_control_host_port = lookup(var.controller_hybrid_config, "slurm_control_host_port", null)
  slurm_control_addr      = lookup(var.controller_hybrid_config, "slurm_control_addr", null)
  slurm_bin_dir           = lookup(var.controller_hybrid_config, "slurm_bin_dir", null)
  slurm_log_dir           = lookup(var.controller_hybrid_config, "slurm_log_dir", null)
  output_dir              = lookup(var.controller_hybrid_config, "output_dir", null)
  install_dir             = lookup(var.controller_hybrid_config, "install_dir", null)
  munge_mount             = lookup(var.controller_hybrid_config, "munge_mount", null)

  depends_on = [
    module.bucket,
  ]
}

##################
# SLURM NODESETS #
##################

data "google_compute_subnetwork" "nodeset_subnetwork" {
  for_each = local.nodeset_map

  project = each.value.subnetwork_project
  region  = each.value.region
  name    = each.value.subnetwork
  self_link = (
    length(regexall("/projects/([^/]*)", each.value.subnetwork)) > 0
    && length(regexall("/regions/([^/]*)", each.value.subnetwork)) > 0
    ? each.value.subnetwork
    : null
  )
}

module "slurm_nodeset_template" {
  source = "./modules/slurm_instance_template"

  for_each = local.nodeset_map

  additional_disks         = each.value.additional_disks
  bandwidth_tier           = each.value.bandwidth_tier
  slurm_bucket_path        = module.slurm_files.slurm_bucket_path
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
  name_prefix              = each.value.nodeset_name
  on_host_maintenance      = each.value.on_host_maintenance
  preemptible              = each.value.preemptible
  project_id               = var.project_id
  service_account          = each.value.service_account
  shielded_instance_config = each.value.shielded_instance_config
  slurm_cluster_name       = var.slurm_cluster_name
  slurm_instance_role      = "compute"
  source_image_family      = each.value.source_image_family
  source_image_project     = each.value.source_image_project
  source_image             = each.value.source_image
  subnetwork               = data.google_compute_subnetwork.nodeset_subnetwork[each.key].self_link
  tags                     = concat([var.slurm_cluster_name], each.value.tags)
}

module "slurm_nodeset" {
  source = "./modules/slurm_nodeset"

  for_each = local.nodeset_map

  enable_placement            = each.value.enable_placement
  enable_public_ip            = each.value.enable_public_ip
  network_tier                = each.value.network_tier
  node_count_dynamic_max      = each.value.node_count_dynamic_max
  node_count_static           = each.value.node_count_static
  nodeset_name                = each.value.nodeset_name
  node_conf                   = each.value.node_conf
  instance_template_self_link = module.slurm_nodeset_template[each.key].self_link
  reservation_name            = each.value.reservation_name
  subnetwork_self_link        = data.google_compute_subnetwork.nodeset_subnetwork[each.key].self_link
  zones                       = each.value.zones
  zone_target_shape           = each.value.zone_target_shape
}

module "slurm_nodeset_dyn" {
  source = "./modules/slurm_nodeset_dyn"

  for_each = local.nodeset_dyn_map

  nodeset_name    = each.value.nodeset_name
  nodeset_feature = each.value.nodeset_feature
}

module "slurm_nodeset_tpu" {
  source = "./modules/slurm_nodeset_tpu"

  for_each = local.nodeset_tpu_map

  node_count_dynamic_max = each.value.node_count_dynamic_max
  node_count_static      = each.value.node_count_static
  nodeset_name           = each.value.nodeset_name
  zone                   = each.value.zone
  node_type              = each.value.node_type
  accelerator_config     = each.value.accelerator_config
  tf_version             = each.value.tf_version
  preemptible            = each.value.preemptible
  reserved               = each.value.reserved
  preserve_tpu           = each.value.preserve_tpu
  enable_public_ip       = each.value.enable_public_ip
  service_account        = each.value.service_account
  data_disks             = each.value.data_disks
  docker_image           = each.value.docker_image
  project_id             = var.project_id
  subnetwork             = each.value.subnetwork
}

###################
# SLURM PARTITION #
###################

module "slurm_partition" {
  source = "./modules/slurm_partition"

  for_each = local.partition_map

  default               = each.value.default
  enable_job_exclusive  = each.value.enable_job_exclusive
  network_storage       = each.value.network_storage
  partition_name        = each.value.partition_name
  partition_conf        = each.value.partition_conf
  partition_nodeset     = [for x in each.value.partition_nodeset : module.slurm_nodeset[x].nodeset_name if try(module.slurm_nodeset[x], null) != null]
  partition_nodeset_dyn = [for x in each.value.partition_nodeset_dyn : module.slurm_nodeset_dyn[x].nodeset_name if try(module.slurm_nodeset_dyn[x], null) != null]
  partition_nodeset_tpu = [for x in each.value.partition_nodeset_tpu : module.slurm_nodeset_tpu[x].nodeset_name if try(module.slurm_nodeset_tpu[x], null) != null]
  resume_timeout        = each.value.resume_timeout
  suspend_time          = each.value.suspend_time
  suspend_timeout       = each.value.suspend_timeout
}

########################
# CONTROLLER: TEMPLATE #
########################

module "slurm_controller_template" {
  source = "./modules/slurm_instance_template"

  count = var.enable_hybrid || local.have_template ? 0 : 1

  additional_disks         = var.controller_instance_config.additional_disks
  bandwidth_tier           = var.controller_instance_config.bandwidth_tier
  slurm_bucket_path        = module.slurm_files.slurm_bucket_path
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
  spot                     = var.controller_instance_config.spot
  subnetwork_project       = var.controller_instance_config.subnetwork_project
  subnetwork               = var.controller_instance_config.subnetwork
  tags                     = concat([var.slurm_cluster_name], var.controller_instance_config.tags)
  termination_action       = var.controller_instance_config.termination_action
}

########################
# CONTROLLER: INSTANCE #
########################

module "slurm_controller_instance" {
  source = "./modules/slurm_controller_instance"

  count = var.enable_hybrid ? 0 : 1

  cloudsql           = var.cloudsql
  enable_public_ip   = var.controller_instance_config.enable_public_ip
  instance_template  = local.have_template ? var.controller_instance_config.instance_template : module.slurm_controller_template[0].self_link
  network_tier       = var.controller_instance_config.network_tier
  project_id         = var.project_id
  region             = var.controller_instance_config.region
  slurm_cluster_name = var.slurm_cluster_name
  static_ips         = var.controller_instance_config.static_ip != null ? [var.controller_instance_config.static_ip] : []
  subnetwork         = var.controller_instance_config.subnetwork
  zone               = var.controller_instance_config.zone

  enable_cleanup_compute = var.enable_cleanup_compute

  depends_on = [
    module.bucket,
  ]
}

######################
# CONTROLLER: HYBRID #
######################

module "slurm_controller_hybrid" {
  source = "./modules/slurm_controller_hybrid"

  count = var.enable_hybrid ? 1 : 0

  project_id         = var.project_id
  slurm_cluster_name = var.slurm_cluster_name

  config                 = module.slurm_files.config
  enable_cleanup_compute = var.enable_cleanup_compute

  depends_on = [
    module.bucket,
  ]
}

###################
# LOGIN: TEMPLATE #
###################

module "slurm_login_template" {
  source = "./modules/slurm_instance_template"

  for_each = var.enable_login ? {
    for x in var.login_nodes : x.group_name => x
    if(x.instance_template == null || x.instance_template == "")
  } : {}

  additional_disks         = each.value.additional_disks
  bandwidth_tier           = each.value.bandwidth_tier
  slurm_bucket_path        = module.slurm_files.slurm_bucket_path
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
  name_prefix              = each.value.group_name
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
  spot                     = each.value.spot
  subnetwork_project       = each.value.subnetwork_project
  subnetwork               = each.value.subnetwork
  tags                     = concat([var.slurm_cluster_name], each.value.tags)
  termination_action       = each.value.termination_action
}

###################
# LOGIN: INSTANCE #
###################

module "slurm_login_instance" {
  source = "./modules/slurm_login_instance"

  for_each = var.enable_login ? { for x in var.login_nodes : x.group_name => x } : {}

  enable_public_ip = each.value.enable_public_ip
  instance_template = (
    each.value.instance_template != null && each.value.instance_template != ""
    ? each.value.instance_template
    : module.slurm_login_template[each.key].self_link
  )
  network_tier       = each.value.network_tier
  num_instances      = each.value.num_instances
  project_id         = var.project_id
  region             = each.value.region
  slurm_cluster_name = var.slurm_cluster_name
  static_ips         = each.value.static_ips
  subnetwork         = each.value.subnetwork
  suffix             = each.key
  zone               = each.value.zone

  depends_on = [
    module.slurm_controller_instance,
  ]
}
