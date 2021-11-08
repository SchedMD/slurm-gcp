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

  scripts_dir = "${path.module}/../../../scripts"

  metadata = {
    enable-oslogin = "TRUE"
    VmDnsSetting   = "GlobalOnly"
  }

  metadata_login = {
    cluster_name  = var.cluster_name
    cluster_id    = var.cluster_id
    instance_type = "login"

    network_storage       = jsonencode(var.network_storage)
    login_network_storage = jsonencode(var.login_network_storage)

    config = jsonencode({
      cluster_name = var.cluster_name
      project      = local.project_id

      munge_key = var.munge_key
      serf_keys = var.serf_keys

      network_storage       = var.network_storage
      login_network_storage = var.login_network_storage
    })
  }
}

########
# DATA #
########

data "local_file" "startup" {
  filename = "${local.scripts_dir}/startup.sh"
}

############
# INSTANCE #
############

module "slurm_login_instance" {
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
  instance_template = var.instance_template
  hostname          = "${var.cluster_name}-login-${local.region}"
  num_instances     = var.num_instances

  ### metadata ###
  metadata_startup_script = data.local_file.startup.content
  metadata = merge(
    local.metadata,
    local.metadata_login,
    var.metadata,
  )
}
