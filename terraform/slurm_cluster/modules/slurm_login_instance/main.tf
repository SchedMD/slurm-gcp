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

  service_account_email = (
    var.enable_reconfigure
    ? data.google_compute_instance_template.login_template[0].service_account[0].email
    : null
  )
}

##########
# RANDOM #
##########

resource "random_string" "suffix" {
  length  = 8
  upper   = false
  special = false
}

##################
# DATA: TEMPLATE #
##################

data "google_compute_instance_template" "login_template" {
  count = var.enable_reconfigure ? 1 : 0

  name = var.instance_template
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

  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}

##########
# PUBSUB #
##########

module "slurm_pubsub" {
  source  = "terraform-google-modules/pubsub/google"
  version = "~> 3.0"

  count = var.enable_reconfigure ? 1 : 0

  project_id = var.project_id
  topic      = var.pubsub_topic

  create_topic        = false
  grant_token_creator = false

  pull_subscriptions = [
    for hostname in module.slurm_login_instance.names : {
      name                    = hostname
      ack_deadline_seconds    = 120
      enable_message_ordering = true
      maximum_backoff         = "300s"
      minimum_backoff         = "30s"
    }
  ]

  subscription_labels = {
    slurm_cluster_name = var.slurm_cluster_name
  }
}

resource "google_pubsub_subscription_iam_member" "controller_pull_subscription_sa_binding_subscriber" {
  for_each = var.enable_reconfigure ? toset(module.slurm_login_instance.names) : []

  project      = var.project_id
  subscription = each.value
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${local.service_account_email}"

  depends_on = [
    module.slurm_pubsub,
  ]
}
