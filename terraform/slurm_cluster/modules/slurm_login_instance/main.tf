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
  region = (
    length(regexall("/regions/([^/]*)", var.subnetwork)) > 0
    ? flatten(regexall("/regions/([^/]*)", var.subnetwork))[0]
    : var.region
  )

  access_config = {
    nat_ip       = null
    network_tier = var.network_tier
  }
}

############
# INSTANCE #
############

module "slurm_login_instance" {
  source = "../_slurm_instance"

  access_config       = var.enable_public_ip ? [local.access_config] : []
  add_hostname_suffix = true
  hostname            = "${var.slurm_cluster_name}-login-${var.suffix}"
  instance_template   = var.instance_template
  network             = var.network
  num_instances       = var.num_instances
  project_id          = var.project_id
  region              = local.region
  slurm_cluster_name  = var.slurm_cluster_name
  slurm_instance_role = "login"
  static_ips          = var.static_ips
  subnetwork_project  = var.subnetwork_project
  subnetwork          = var.subnetwork
  zone                = var.zone
}
