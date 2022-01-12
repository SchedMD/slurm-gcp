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
  project_id = (
    length(regexall("/projects/([^/]*)", var.instance_template)) > 0
    ? flatten(regexall("/projects/([^/]*)", var.instance_template))[0]
    : null
  )

  etc_dir = abspath("${path.module}/../../../etc")
}

##################
# LOCALS: CONFIG #
##################

locals {
  slurm_cluster_id = (
    var.slurm_cluster_id == null || var.slurm_cluster_id == ""
    ? random_uuid.slurm_cluster_id.result
    : var.slurm_cluster_id
  )

  munge_key = (
    var.munge_key == null
    ? random_id.munge_key.b64_std
    : var.munge_key
  )

  jwt_key = (
    var.jwt_key == null
    ? random_id.jwt_key.b64_std
    : var.jwt_key
  )

  partitions = { for p in var.partitions : p.partition_name => p }
}

####################
# LOCALS: METADATA #
####################

locals {
  metadata_config = {
    cluster_name = var.cluster_name
    project      = local.project_id

    cloudsql  = jsonencode(var.cloudsql)
    munge_key = local.munge_key
    jwt_key   = local.jwt_key
    pubsub = jsonencode({
      topic_id        = module.slurm_pubsub.topic
      subscription_id = module.slurm_pubsub.pubsub.subscription_names[0]
    })

    network_storage       = jsonencode(var.network_storage)
    login_network_storage = jsonencode(var.login_network_storage)

    cloud_parameters = jsonencode({
      ResumeRate     = lookup(var.cloud_parameters, "ResumeRate", 0)
      SuspendRate    = lookup(var.cloud_parameters, "SuspendRate", 0)
      ResumeTimeout  = lookup(var.cloud_parameters, "ResumeTimeout", 300)
      SuspendTimeout = lookup(var.cloud_parameters, "SuspendTimeout", 300)
    })
    partitions = jsonencode(local.partitions)
  }

  metadata_tpl = {
    cgroup_conf_tpl   = data.local_file.cgroup_conf_tpl.content
    slurm_conf_tpl    = data.local_file.slurm_conf_tpl.content
    slurmdbd_conf_tpl = data.local_file.slurmdbd_conf_tpl.content
  }
}

###################
# LOCALS: SCRIPTS #
###################

locals {
  scripts_controller_d = {
    for script in var.controller_d
    : "custom-controller-${basename(script.filename)}"
    => script.content
  }

  scripts_compute_d = {
    for script in var.compute_d
    : "custom-compute-${basename(script.filename)}"
    => script.content
  }
}

################
# LOCALS: CONF #
################

locals {
  slurmdbd_conf_tpl = (
    var.slurmdbd_conf_tpl == null
    ? abspath("${local.etc_dir}/slurmdbd.conf.tpl")
    : abspath(var.slurmdbd_conf_tpl)
  )

  slurm_conf_tpl = (
    var.slurm_conf_tpl == null
    ? abspath("${local.etc_dir}/slurm.conf.tpl")
    : abspath(var.slurm_conf_tpl)
  )

  cgroup_conf_tpl = (
    var.cgroup_conf_tpl == null
    ? abspath("${local.etc_dir}/cgroup.conf.tpl")
    : abspath(var.cgroup_conf_tpl)
  )
}

##############
# DATA: CONF #
##############

data "local_file" "slurmdbd_conf_tpl" {
  filename = local.slurmdbd_conf_tpl
}

data "local_file" "slurm_conf_tpl" {
  filename = local.slurm_conf_tpl
}

data "local_file" "cgroup_conf_tpl" {
  filename = local.cgroup_conf_tpl
}

##########
# RANDOM #
##########

resource "random_uuid" "slurm_cluster_id" {
}

resource "random_id" "munge_key" {
  byte_length = 256
}

resource "random_id" "jwt_key" {
  byte_length = 256
}

############
# INSTANCE #
############

module "slurm_controller_instance" {
  source  = "terraform-google-modules/vm/google//modules/compute_instance"
  version = "~> 7.1"

  ### network ###
  subnetwork_project = var.subnetwork_project
  network            = var.network
  subnetwork         = var.subnetwork
  region             = var.region
  zone               = var.zone
  static_ips         = var.static_ips
  access_config      = var.access_config

  ### instance ###
  instance_template   = var.instance_template
  hostname            = "${var.cluster_name}-controller"
  add_hostname_suffix = false

  depends_on = [
    module.slurm_metadata,
  ]
}

############
# METADATA #
############

module "slurm_metadata" {
  source = "../_slurm_metadata"

  cluster_name = var.cluster_name
  enable_devel = var.enable_devel
  metadata = merge(
    local.metadata_config,
    local.metadata_tpl,
    local.scripts_controller_d,
    local.scripts_compute_d,
  )
  project_id = local.project_id
}

##########
# PUBSUB #
##########

module "slurm_pubsub" {
  source = "../_slurm_pubsub"

  cluster_name     = var.cluster_name
  project_id       = local.project_id
  slurm_cluster_id = local.slurm_cluster_id
}

#################
# DESTROY NODES #
#################

module "slurm_destroy_nodes" {
  source = "../slurm_destroy_nodes"

  slurm_cluster_id = local.slurm_cluster_id
}
