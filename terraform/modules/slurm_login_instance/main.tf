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
  region = (
    length(regexall("/regions/([^/]*)", var.subnetwork)) > 0
    ? flatten(regexall("/regions/([^/]*)", var.subnetwork))[0]
    : var.region
  )
}

############
# INSTANCE #
############

module "slurm_login_instance" {
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
  instance_template = var.instance_template
  hostname          = "${var.cluster_name}-login-${local.region}"
  num_instances     = var.num_instances
}
