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

  service_account_email = (
    var.cloudsql != null
    ? data.google_compute_instance_template.controller_template[0].service_account[0].email
    : null
  )

  access_config = {
    nat_ip       = null
    network_tier = var.network_tier
  }
}

##################
# DATA: TEMPLATE #
##################

data "google_compute_instance_template" "controller_template" {
  count = var.cloudsql != null ? 1 : 0

  name = var.instance_template
}

############
# INSTANCE #
############

module "slurm_controller_instance" {
  source = "../_slurm_instance"

  access_config       = var.enable_public_ip ? [local.access_config] : []
  add_hostname_suffix = false
  hostname            = "${var.slurm_cluster_name}-controller"
  instance_template   = var.instance_template
  network             = var.network
  project_id          = var.project_id
  region              = local.region
  slurm_cluster_name  = var.slurm_cluster_name
  slurm_instance_role = "controller"
  static_ips          = var.static_ips
  subnetwork_project  = var.subnetwork_project
  subnetwork          = var.subnetwork
  zone                = var.zone

  metadata = var.metadata

  depends_on = [
    # Ensure nodes are destroyed before controller is
    module.cleanup_compute_nodes[0],
  ]
}

#####################
# SECRETS: CLOUDSQL #
#####################

resource "google_secret_manager_secret" "cloudsql" {
  count = var.cloudsql != null ? 1 : 0

  secret_id = "${var.slurm_cluster_name}-slurm-secret-cloudsql"

  replication {
    automatic = true
  }

  labels = {
    slurm_cluster_name = var.slurm_cluster_name
  }
}

resource "google_secret_manager_secret_version" "cloudsql_version" {
  count = var.cloudsql != null ? 1 : 0

  secret      = google_secret_manager_secret.cloudsql[0].id
  secret_data = jsonencode(var.cloudsql)
}

resource "google_secret_manager_secret_iam_member" "cloudsql_secret_accessor" {
  count = var.cloudsql != null ? 1 : 0

  secret_id = google_secret_manager_secret.cloudsql[0].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.service_account_email}"
}

#################
# DESTROY NODES #
#################

# Destroy all compute nodes on `terraform destroy`
module "cleanup_compute_nodes" {
  source = "../slurm_destroy_nodes"

  count = var.enable_cleanup_compute ? 1 : 0

  slurm_cluster_name = var.slurm_cluster_name
  project_id         = var.project_id
  when_destroy       = true
}

#############################
# DESTROY RESOURCE POLICIES #
#############################

# Destroy all resource policies on `terraform destroy`
module "cleanup_resource_policies" {
  source = "../slurm_destroy_resource_policies"

  count = var.enable_cleanup_compute ? 1 : 0

  slurm_cluster_name = var.slurm_cluster_name
  project_id         = var.project_id
  when_destroy       = true
}
