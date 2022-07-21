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

  etc_dir = abspath("${path.module}/../../../../etc")

  service_account_email = (
    var.enable_reconfigure || var.cloudsql != null
    ? data.google_compute_instance_template.controller_template[0].service_account[0].email
    : null
  )
}

##################
# LOCALS: CONFIG #
##################

locals {
  partitions   = { for p in var.partitions[*].partition : p.partition_name => p }
  compute_list = flatten(var.partitions[*].compute_list)
}

####################
# LOCALS: METADATA #
####################

locals {
  metadata_config = {
    enable_bigquery_load = var.enable_bigquery_load
    enable_reconfigure   = var.enable_reconfigure
    cloudsql             = var.cloudsql != null ? true : false
    cluster_id           = random_uuid.cluster_id.result
    project              = var.project_id
    pubsub_topic_id      = var.enable_reconfigure ? google_pubsub_topic.this[0].name : null
    slurm_cluster_name   = var.slurm_cluster_name

    # storage
    disable_default_mounts = var.disable_default_mounts
    network_storage        = var.network_storage
    login_network_storage  = var.login_network_storage

    # slurm conf
    prolog_scripts   = [for x in google_compute_project_metadata_item.prolog_scripts : x.key]
    epilog_scripts   = [for x in google_compute_project_metadata_item.epilog_scripts : x.key]
    cloud_parameters = var.cloud_parameters
    partitions       = local.partitions
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

##################
# DATA: TEMPLATE #
##################

data "google_compute_instance_template" "controller_template" {
  count = var.enable_reconfigure || var.cloudsql != null ? 1 : 0

  name = var.instance_template
}

##########
# RANDOM #
##########

resource "random_string" "topic_suffix" {
  length  = 8
  special = false
}

resource "random_uuid" "cluster_id" {

}

############
# INSTANCE #
############

module "slurm_controller_instance" {
  source = "../_slurm_instance"

  access_config       = var.access_config
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

  slurm_depends_on = flatten([
    var.slurm_depends_on,
    [
      google_compute_project_metadata_item.config.id,
      google_compute_project_metadata_item.slurm_conf.id,
      google_compute_project_metadata_item.cgroup_conf.id,
      google_compute_project_metadata_item.slurmdbd_conf.id,
      var.enable_devel ? module.slurm_metadata_devel[0].metadata.id : null,
    ],
  ])
  depends_on = [
    # Ensure delta when user startup scripts change
    google_compute_project_metadata_item.controller_startup_scripts,
    # Ensure nodes are destroyed before controller is
    module.cleanup_compute_nodes[0],
  ]
}

####################
# METADATA: CONFIG #
####################

resource "google_compute_project_metadata_item" "config" {
  project = var.project_id

  key   = "${var.slurm_cluster_name}-slurm-config"
  value = jsonencode(local.metadata_config)
}

resource "google_compute_project_metadata_item" "slurm_conf" {
  project = var.project_id

  key   = "${var.slurm_cluster_name}-slurm-tpl-slurm-conf"
  value = data.local_file.slurm_conf_tpl.content
}

resource "google_compute_project_metadata_item" "cgroup_conf" {
  project = var.project_id

  key   = "${var.slurm_cluster_name}-slurm-tpl-cgroup-conf"
  value = data.local_file.cgroup_conf_tpl.content
}

resource "google_compute_project_metadata_item" "slurmdbd_conf" {
  project = var.project_id

  key   = "${var.slurm_cluster_name}-slurm-tpl-slurmdbd-conf"
  value = data.local_file.slurmdbd_conf_tpl.content
}

###################
# METADATA: DEVEL #
###################

module "slurm_metadata_devel" {
  source = "../_slurm_metadata_devel"

  count = var.enable_devel ? 1 : 0

  slurm_cluster_name = var.slurm_cluster_name
  project_id         = var.project_id
}

#####################
# METADATA: SCRIPTS #
#####################

resource "google_compute_project_metadata_item" "controller_startup_scripts" {
  project = var.project_id

  for_each = {
    for x in var.controller_startup_scripts
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  key   = "${var.slurm_cluster_name}-slurm-controller-script-${each.key}"
  value = each.value.content
}

resource "google_compute_project_metadata_item" "compute_startup_scripts" {
  project = var.project_id

  for_each = {
    for x in var.compute_startup_scripts
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  key   = "${var.slurm_cluster_name}-slurm-compute-script-${each.key}"
  value = each.value.content
}

resource "google_compute_project_metadata_item" "prolog_scripts" {
  project = var.project_id

  for_each = {
    for x in var.prolog_scripts
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  key   = "${var.slurm_cluster_name}-slurm-prolog-script-${each.key}"
  value = each.value.content
}

resource "google_compute_project_metadata_item" "epilog_scripts" {
  project = var.project_id

  for_each = {
    for x in var.epilog_scripts
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  key   = "${var.slurm_cluster_name}-slurm-epilog-script-${each.key}"
  value = each.value.content
}

##################
# PUBSUB: SCHEMA #
##################

resource "google_pubsub_schema" "this" {
  count = var.enable_reconfigure ? 1 : 0

  name       = "${var.slurm_cluster_name}-slurm-events"
  type       = "PROTOCOL_BUFFER"
  definition = <<EOD
syntax = "proto3";
message Results {
  string request = 1;
  string timestamp = 2;
}
EOD

  lifecycle {
    create_before_destroy = true
  }
}

#################
# PUBSUB: TOPIC #
#################

resource "google_pubsub_topic" "this" {
  count = var.enable_reconfigure ? 1 : 0

  name = "${var.slurm_cluster_name}-slurm-events-${random_string.topic_suffix.result}"

  schema_settings {
    schema   = google_pubsub_schema.this[0].id
    encoding = "JSON"
  }

  labels = {
    slurm_cluster_name = var.slurm_cluster_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_pubsub_topic_iam_member" "topic_publisher" {
  count = var.enable_reconfigure ? 1 : 0

  project = var.project_id
  topic   = google_pubsub_topic.this[0].id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${local.service_account_email}"
}

##########
# PUBSUB #
##########

module "slurm_pubsub" {
  source  = "terraform-google-modules/pubsub/google"
  version = "~> 3.0"

  count = var.enable_reconfigure ? 1 : 0

  project_id = var.project_id
  topic      = google_pubsub_topic.this[0].id

  create_topic        = false
  grant_token_creator = false

  pull_subscriptions = [
    {
      name                    = module.slurm_controller_instance.instances_details[0].name
      ack_deadline_seconds    = 120
      enable_message_ordering = true
      maximum_backoff         = "300s"
      minimum_backoff         = "30s"
    },
  ]

  subscription_labels = {
    slurm_cluster_name = var.slurm_cluster_name
  }
}

resource "google_pubsub_subscription_iam_member" "controller_pull_subscription_sa_binding_subscriber" {
  count = var.enable_reconfigure ? 1 : 0

  project      = var.project_id
  subscription = module.slurm_controller_instance.instances_details[0].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${local.service_account_email}"

  depends_on = [
    module.slurm_pubsub,
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

####################
# NOTIFY: RECONFIG #
####################

module "reconfigure_notify" {
  source = "../slurm_notify_cluster"

  count = var.enable_reconfigure ? 1 : 0

  topic = google_pubsub_topic.this[0].name
  type  = "reconfig"

  triggers = {
    compute_list  = join(",", local.compute_list)
    config        = sha256(google_compute_project_metadata_item.config.value)
    cgroup_conf   = sha256(google_compute_project_metadata_item.cgroup_conf.value)
    slurm_conf    = sha256(google_compute_project_metadata_item.slurm_conf.value)
    slurmdbd_conf = sha256(google_compute_project_metadata_item.slurmdbd_conf.value)
  }

  depends_on = [
    # Ensure subscriptions are created
    module.slurm_pubsub,
    # Ensure controller is created
    module.slurm_controller_instance.slurm_instances,
  ]
}

#################
# NOTIFY: DEVEL #
#################

module "devel_notify" {
  source = "../slurm_notify_cluster"

  count = var.enable_devel && var.enable_reconfigure ? 1 : 0

  topic = google_pubsub_topic.this[0].name
  type  = "devel"

  triggers = {
    devel = sha256(module.slurm_metadata_devel[0].metadata.value)
  }

  depends_on = [
    # Ensure subscriptions are created
    module.slurm_pubsub,
    # Ensure controller is created
    module.slurm_controller_instance,
  ]
}

#################
# DESTROY NODES #
#################

# Destroy all compute nodes on `terraform destroy`
module "cleanup_compute_nodes" {
  source = "../slurm_destroy_nodes"

  count = var.enable_cleanup_compute ? 1 : 0

  slurm_cluster_name = var.slurm_cluster_name
  when_destroy       = true
}

module "cleanup_subscriptions" {
  source = "../slurm_destroy_subscriptions"

  count = var.enable_cleanup_subscriptions ? 1 : 0

  slurm_cluster_name = var.slurm_cluster_name
  when_destroy       = true
}

# Destroy all compute nodes when the compute node environment changes
module "reconfigure_critical" {
  source = "../slurm_destroy_nodes"

  count = var.enable_reconfigure ? 1 : 0

  slurm_cluster_name = var.slurm_cluster_name

  triggers = merge(
    {
      for x in var.compute_startup_scripts
      : "compute_d_${replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_")}"
      => sha256(x.content)
    },
    {
      for x in var.prolog_scripts
      : "prolog_d_${replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_")}"
      => sha256(x.content)
    },
    {
      for x in var.epilog_scripts
      : "epilog_d_${replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_")}"
      => sha256(x.content)
    },
    {
      controller_id = module.slurm_controller_instance.instances_details[0].instance_id
    },
  )
}

# Destroy all removed compute nodes when partitions change
module "reconfigure_partitions" {
  source = "../slurm_destroy_nodes"

  count = var.enable_reconfigure ? 1 : 0

  slurm_cluster_name = var.slurm_cluster_name
  exclude_list       = local.compute_list

  triggers = {
    compute_list = join(",", local.compute_list)
  }

  depends_on = [
    # Prevent race condition
    module.reconfigure_critical,
  ]
}

#############################
# DESTROY RESOURCE POLICIES #
#############################

# Destroy all resource policies on `terraform destroy`
module "cleanup_resource_policies" {
  source = "../slurm_destroy_resource_policies"

  count = var.enable_cleanup_compute ? 1 : 0

  slurm_cluster_name = var.slurm_cluster_name
  when_destroy       = true
}
