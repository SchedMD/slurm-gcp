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

  suffix = random_string.suffix.result
}

##########
# RANDOM #
##########

resource "random_string" "suffix" {
  length  = 8
  upper   = false
  special = false
}

############
# INSTANCE #
############

module "slurm_login_instance" {
  source = "../_slurm_instance"

  access_config       = var.access_config
  add_hostname_suffix = true
  hostname            = "${var.slurm_cluster_name}-login-${local.suffix}"
  instance_template   = var.instance_template
  metadata = merge(
    var.metadata,
    {
      slurm_login_suffix = local.suffix
    },
  )
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

  slurm_depends_on = var.slurm_depends_on
  depends_on = [
    # Ensure delta when user startup scripts change
    google_compute_project_metadata_item.login_startup_scripts,
  ]
}

###########
# SCRIPTS #
###########

resource "google_compute_project_metadata_item" "login_startup_scripts" {
  project = var.project_id

  for_each = {
    for x in var.login_startup_scripts
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  key   = "${var.slurm_cluster_name}-slurm-login_${local.suffix}-script-${each.key}"
  value = each.value.content
}
