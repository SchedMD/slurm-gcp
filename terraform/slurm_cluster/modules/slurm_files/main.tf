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

locals {
  scripts_dir = abspath("${path.module}/../../../../scripts")

  bucket_dir = coalesce(var.bucket_dir, format("%s-files", var.slurm_cluster_name))
}

########
# DATA #
########

data "google_storage_bucket" "this" {
  name = var.bucket_name
}

##########
# RANDOM #
##########

resource "random_uuid" "cluster_id" {
}

##################
# CLUSTER CONFIG #
##################

locals {
  config = {
    enable_bigquery_load = var.enable_bigquery_load
    cloudsql_secret      = var.cloudsql_secret
    cluster_id           = random_uuid.cluster_id.result
    project              = var.project_id
    slurm_cluster_name   = var.slurm_cluster_name
    bucket_path          = local.bucket_path
    enable_debug_logging = var.enable_debug_logging
    extra_logging_flags  = var.extra_logging_flags

    # storage
    disable_default_mounts = var.disable_default_mounts
    network_storage        = var.network_storage
    login_network_storage  = var.enable_hybrid ? null : var.login_network_storage

    # timeouts
    controller_startup_scripts_timeout = var.enable_hybrid ? null : var.controller_startup_scripts_timeout
    compute_startup_scripts_timeout    = var.compute_startup_scripts_timeout
    login_startup_scripts_timeout      = var.enable_hybrid ? null : var.login_startup_scripts_timeout
    munge_mount                        = local.munge_mount

    # slurm conf
    prolog_scripts   = [for k, v in google_storage_bucket_object.prolog_scripts : k]
    epilog_scripts   = [for k, v in google_storage_bucket_object.epilog_scripts : k]
    cloud_parameters = var.cloud_parameters
    partitions       = local.partitions
    nodeset          = local.nodeset
    nodeset_dyn      = local.nodeset_dyn
    nodeset_tpu      = local.nodeset_tpu

    # hybrid
    hybrid                  = var.enable_hybrid
    google_app_cred_path    = var.enable_hybrid ? local.google_app_cred_path : null
    output_dir              = var.enable_hybrid ? local.output_dir : null
    install_dir             = var.enable_hybrid ? local.install_dir : null
    slurm_control_host      = var.enable_hybrid ? var.slurm_control_host : null
    slurm_control_host_port = var.enable_hybrid ? local.slurm_control_host_port : null
    slurm_control_addr      = var.enable_hybrid ? var.slurm_control_addr : null
    slurm_bin_dir           = var.enable_hybrid ? local.slurm_bin_dir : null
    slurm_log_dir           = var.enable_hybrid ? local.slurm_log_dir : null
  }

  config_yaml        = "config.yaml"
  config_yaml_bucket = format("%s/%s", local.bucket_dir, local.config_yaml)

  partitions = { for p in var.partitions[*].partition : p.partition_name => p }

  nodeset     = { for n in var.nodeset[*].nodeset : n.nodeset_name => n }
  nodeset_dyn = { for n in var.nodeset_dyn[*].nodeset : n.nodeset_name => n }
  nodeset_tpu = { for n in var.nodeset_tpu[*].nodeset : n.nodeset_name => n }

  x_nodeset         = toset([for k, v in local.nodeset : v.nodeset_name])
  x_nodeset_dyn     = toset([for k, v in local.nodeset_dyn : v.nodeset_name])
  x_nodeset_tpu     = toset([for k, v in local.nodeset_tpu : v.nodeset_name])
  x_nodeset_overlap = setintersection([], local.x_nodeset, local.x_nodeset_dyn, local.x_nodeset_tpu)

  etc_dir = abspath("${path.module}/../../../../etc")

  bucket_path = format("%s/%s", data.google_storage_bucket.this.url, local.bucket_dir)

  slurm_control_host_port = coalesce(var.slurm_control_host_port, "6818")

  google_app_cred_path = var.google_app_cred_path != null ? abspath(var.google_app_cred_path) : null
  slurm_bin_dir        = var.slurm_bin_dir != null ? abspath(var.slurm_bin_dir) : null
  slurm_log_dir        = var.slurm_log_dir != null ? abspath(var.slurm_log_dir) : null

  munge_mount = var.enable_hybrid ? {
    server_ip     = lookup(var.munge_mount, "server_ip", coalesce(var.slurm_control_addr, var.slurm_control_host))
    remote_mount  = lookup(var.munge_mount, "remote_mount", "/etc/munge/")
    fs_type       = lookup(var.munge_mount, "fs_type", "nfs")
    mount_options = lookup(var.munge_mount, "mount_options", "")
  } : null

  output_dir  = can(coalesce(var.output_dir)) ? abspath(var.output_dir) : abspath(".")
  install_dir = can(coalesce(var.install_dir)) ? abspath(var.install_dir) : local.output_dir
}

resource "google_storage_bucket_object" "config" {
  bucket  = data.google_storage_bucket.this.name
  name    = local.config_yaml_bucket
  content = yamlencode(local.config)
}

#########
# DEVEL #
#########

locals {
  build_dir = abspath("${path.module}/../../../../build")

  slurm_gcp_devel_zip        = "slurm-gcp-devel.zip"
  slurm_gcp_devel_zip_bucket = format("%s/%s", local.bucket_dir, local.slurm_gcp_devel_zip)
}

data "archive_file" "slurm_gcp_devel_zip" {
  count = var.enable_devel ? 1 : 0

  output_path = "${local.build_dir}/${local.slurm_gcp_devel_zip}"
  type        = "zip"
  source_dir  = local.scripts_dir

  excludes = flatten([
    "config.yaml",
    "Pipfile",
    fileset(local.scripts_dir, "__pycache__/*"),
    fileset(local.scripts_dir, "*.log"),
    fileset(local.scripts_dir, "*.cache"),
    fileset(local.scripts_dir, "*.lock"),
  ])
}

resource "google_storage_bucket_object" "devel" {
  count = var.enable_devel ? 1 : 0

  bucket = var.bucket_name
  name   = local.slurm_gcp_devel_zip_bucket
  source = data.archive_file.slurm_gcp_devel_zip[0].output_path
}

##############
# CONF FILES #
##############

data "local_file" "slurmdbd_conf_tpl" {
  filename = abspath(coalesce(var.slurmdbd_conf_tpl, "${local.etc_dir}/slurmdbd.conf.tpl"))
}

resource "google_storage_bucket_object" "slurmdbd_conf_tpl" {
  bucket  = var.bucket_name
  name    = format("%s/slurm-tpl-slurmdbd-conf", local.bucket_dir)
  content = data.local_file.slurmdbd_conf_tpl.content
}

data "local_file" "slurm_conf_tpl" {
  filename = abspath(coalesce(var.slurm_conf_tpl, "${local.etc_dir}/slurm.conf.tpl"))
}

resource "google_storage_bucket_object" "slurm_conf_tpl" {
  bucket  = var.bucket_name
  name    = format("%s/slurm-tpl-slurm-conf", local.bucket_dir)
  content = data.local_file.slurm_conf_tpl.content
}

data "local_file" "cgroup_conf_tpl" {
  filename = abspath(coalesce(var.cgroup_conf_tpl, "${local.etc_dir}/cgroup.conf.tpl"))
}

resource "google_storage_bucket_object" "cgroup_conf_tpl" {
  bucket  = var.bucket_name
  name    = format("%s/slurm-tpl-cgroup-conf", local.bucket_dir)
  content = data.local_file.cgroup_conf_tpl.content
}

data "local_file" "jobsubmit_lua_tpl" {
  filename = abspath(coalesce(var.job_submit_lua_tpl, "${local.etc_dir}/job_submit.lua.tpl"))
}

resource "google_storage_bucket_object" "jobsubmit_lua_tpl" {
  bucket  = var.bucket_name
  name    = format("%s/slurm-tpl-job-submit-lua", local.bucket_dir)
  content = data.local_file.jobsubmit_lua_tpl.content
}

###########
# SCRIPTS #
###########

resource "google_storage_bucket_object" "controller_startup_scripts" {
  for_each = {
    for x in var.controller_startup_scripts
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  bucket  = var.bucket_name
  name    = format("%s/slurm-controller-script-%s", local.bucket_dir, each.key)
  content = each.value.content
}

resource "google_storage_bucket_object" "compute_startup_scripts" {
  for_each = {
    for x in var.compute_startup_scripts
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  bucket  = var.bucket_name
  name    = format("%s/slurm-compute-script-%s", local.bucket_dir, each.key)
  content = each.value.content
}

resource "google_storage_bucket_object" "login_startup_scripts" {
  for_each = {
    for x in var.login_startup_scripts
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  bucket  = var.bucket_name
  name    = format("%s/slurm-login-script-%s", local.bucket_dir, each.key)
  content = each.value.content
}

resource "google_storage_bucket_object" "prolog_scripts" {
  for_each = {
    for x in var.prolog_scripts
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  bucket  = var.bucket_name
  name    = format("%s/slurm-prolog-script-%s", local.bucket_dir, each.key)
  content = each.value.content
}

resource "google_storage_bucket_object" "epilog_scripts" {
  for_each = {
    for x in var.epilog_scripts
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  bucket  = var.bucket_name
  name    = format("%s/slurm-epilog-script-%s", local.bucket_dir, each.key)
  content = each.value.content
}
