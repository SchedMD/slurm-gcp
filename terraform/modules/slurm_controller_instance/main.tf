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

  region = (
    length(regexall("/regions/([^/]*)", var.subnetwork)) > 0
    ? flatten(regexall("/regions/([^/]*)", var.subnetwork))[0]
    : var.region
  )

  scripts_dir = abspath("${path.module}/../../../scripts")

  etc_dir = abspath("${path.module}/../../../etc")
}

##################
# LOCALS: CONFIG #
##################

locals {
  cluster_name = (
    var.cluster_name == null || var.cluster_name == ""
    ? random_string.cluster_name.result
    : var.cluster_name
  )

  slurm_cluster_id = (
    var.slurm_cluster_id == null || var.slurm_cluster_id == ""
    ? random_uuid.slurm_cluster_id.result
    : var.slurm_cluster_id
  )

  munge_key = module.slurm_controller_common.munge_key

  jwt_key = module.slurm_controller_common.jwt_key

  template_map = module.slurm_controller_common.template_map

  partitions = module.slurm_controller_common.partitions
}

####################
# LOCALS: METADATA #
####################

locals {
  metadata = {
    enable-oslogin = "TRUE"
    VmDnsSetting   = "GlobalOnly"
  }

  metadata_controller = {
    instance_type = "controller"
    cluster_name  = local.cluster_name
    config = jsonencode({
      cluster_name = local.cluster_name
      project      = local.project_id

      cloudsql  = var.cloudsql
      munge_key = local.munge_key
      jwt_key   = local.jwt_key
      pubsub = {
        topic_id        = module.slurm_controller_common.pubsub_topic
        subscription_id = module.slurm_controller_common.pubsub.subscription_names[0]
      }

      network_storage       = var.network_storage
      login_network_storage = var.login_network_storage

      cloud_parameters = {
        ResumeRate          = lookup(var.cloud_parameters, "ResumeRate", 0)
        SuspendRate         = lookup(var.cloud_parameters, "SuspendRate", 0)
        ResumeTimeout       = lookup(var.cloud_parameters, "ResumeTimeout", 300)
        SuspendTimeout      = lookup(var.cloud_parameters, "SuspendTimeout", 300)
        SlurmctldParameters = lookup(var.cloud_parameters, "SlurmctldParameters", "")
      }
      template_map = module.slurm_controller_common.template_map
      partitions   = module.slurm_controller_common.partitions
    })
    cgroup_conf_tpl   = data.local_file.cgroup_conf_tpl.content
    slurm_conf_tpl    = data.local_file.slurm_conf_tpl.content
    slurmdbd_conf_tpl = data.local_file.slurmdbd_conf_tpl.content
  }
}

###################
# LOCALS: SCRIPTS #
###################

locals {
  controller_d = (
    var.controller_d == null
    ? abspath("${local.scripts_dir}/controller.d")
    : abspath(var.controller_d)
  )

  scripts_controller_d = {
    for script in fileset(local.controller_d, "[^.]*")
    : "custom-controller-${replace(script, "/[^a-zA-Z0-9-_]/", "_")}"
    => file("${local.controller_d}/${script}")
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

resource "random_string" "cluster_name" {
  length  = 8
  lower   = true
  upper   = false
  special = false
  number  = false
}

resource "random_uuid" "slurm_cluster_id" {
}

############
# INSTANCE #
############

module "slurm_controller_instance" {
  source = "../_compute_instance"

  ### network ###
  subnetwork_project = var.subnetwork_project
  network            = var.network
  subnetwork         = var.subnetwork
  region             = local.region
  zone               = var.zone
  static_ips         = var.static_ips
  access_config      = var.access_config

  ### instance ###
  instance_template   = var.instance_template
  hostname            = "${local.cluster_name}-controller"
  add_hostname_suffix = false

  ### metadata ###
  metadata = merge(
    local.metadata,
    local.metadata_controller,
    local.scripts_controller_d,
    var.metadata_controller,
  )
}

##########
# COMMON #
##########

module "slurm_controller_common" {
  source = "../_slurm_controller_common"

  project_id = local.project_id

  slurm_cluster_id = local.slurm_cluster_id
  cluster_name     = local.cluster_name
  munge_key        = var.munge_key
  jwt_key          = var.jwt_key
  template_map     = var.template_map
  partitions       = var.partitions
  metadata_compute = var.metadata_compute
  compute_d        = var.compute_d
  enable_devel     = var.enable_devel
}
