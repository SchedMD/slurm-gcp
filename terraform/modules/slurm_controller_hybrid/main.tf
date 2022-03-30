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
  scripts_dir = abspath("${path.module}/../../../scripts")

  output_dir = (
    var.output_dir == null || var.output_dir == ""
    ? abspath(".")
    : abspath(var.output_dir)
  )
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

  partitions   = { for p in var.partitions[*].partition : p.partition_name => p }
  compute_list = flatten(var.partitions[*].compute_list)
  sa_node_map  = merge(flatten(var.partitions[*].sa_node_map)...)

  google_app_cred_path = (
    var.google_app_cred_path != null
    ? abspath(var.google_app_cred_path)
    : null
  )

  slurm_bin_dir = (
    var.slurm_bin_dir != null
    ? abspath(var.slurm_bin_dir)
    : null
  )

  slurm_log_dir = (
    var.slurm_log_dir != null
    ? abspath(var.slurm_log_dir)
    : null
  )

  config = yamlencode({
    enable_bigquery_load = var.enable_bigquery_load
    enable_reconfigure   = var.enable_reconfigure
    project              = var.project_id
    pubsub_topic_id      = var.enable_reconfigure ? google_pubsub_topic.this[0].name : null
    slurm_cluster_id     = local.slurm_cluster_id
    slurm_cluster_name   = var.slurm_cluster_name

    # storage
    network_storage       = var.network_storage
    login_network_storage = var.login_network_storage

    # slurm conf
    prolog_d         = [for x in google_compute_project_metadata_item.prolog_d : x.key]
    epilog_d         = [for x in google_compute_project_metadata_item.epilog_d : x.key]
    cloud_parameters = var.cloud_parameters
    partitions       = local.partitions

    # hybrid
    google_app_cred_path = local.google_app_cred_path
    output_dir           = local.output_dir
    slurm_bin_dir        = local.slurm_bin_dir
    slurm_log_dir        = local.slurm_log_dir
  })
}

################
# DATA: SCRIPT #
################

data "local_file" "setup_hybrid_py" {
  filename = abspath("${local.scripts_dir}/setup_hybrid.py")
}

data "local_file" "resume_py" {
  filename = abspath("${local.scripts_dir}/resume.py")
}

data "local_file" "suspend_py" {
  filename = abspath("${local.scripts_dir}/suspend.py")
}

data "local_file" "util_py" {
  filename = abspath("${local.scripts_dir}/util.py")
}

data "local_file" "slurmsync_py" {
  filename = abspath("${local.scripts_dir}/slurmsync.py")
}

##########
# RANDOM #
##########

resource "random_uuid" "slurm_cluster_id" {
}

resource "random_string" "topic_suffix" {
  length  = 8
  special = false
}

###########
# SCRIPTS #
###########

resource "local_file" "resume_py" {
  content  = data.local_file.resume_py.content
  filename = abspath("${var.output_dir}/resume.py")
}

resource "local_file" "suspend_py" {
  content  = data.local_file.suspend_py.content
  filename = abspath("${var.output_dir}/suspend.py")
}

resource "local_file" "util_py" {
  content  = data.local_file.util_py.content
  filename = abspath("${var.output_dir}/util.py")
}

resource "local_file" "slurmsync_py" {
  content  = data.local_file.slurmsync_py.content
  filename = abspath("${var.output_dir}/slurmsync.py")
}

##########
# CONFIG #
##########

resource "local_file" "config_yaml" {
  filename = abspath("${local.output_dir}/config.yaml")
  content  = local.config

  file_permission = "0644"
}

#########
# SETUP #
#########

resource "null_resource" "setup_hybrid" {
  triggers = merge({
    scripts_dir = local.scripts_dir
    config_dir  = local.output_dir
    config      = local_file.config_yaml.content
    config_path = local_file.config_yaml.filename
    script_path = data.local_file.setup_hybrid_py.filename

    no_comma_params = var.cloud_parameters.no_comma_params
    resume_rate     = var.cloud_parameters.resume_rate
    resume_timeout  = var.cloud_parameters.resume_timeout
    suspend_rate    = var.cloud_parameters.suspend_rate
    suspend_timeout = var.cloud_parameters.suspend_timeout
    },
    {
      for x in var.prolog_d
      : "prolog_d_${replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_")}"
      => sha256(x.content)
    },
    {
      for x in var.epilog_d
      : "epilog_d_${replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_")}"
      => sha256(x.content)
    },
  )

  provisioner "local-exec" {
    working_dir = self.triggers.scripts_dir
    environment = {
      SLURM_CONFIG_YAML = self.triggers.config_path
    }
    command = <<EOC
${self.triggers.script_path} \
--resume-rate=${self.triggers.resume_rate} \
--suspend-rate=${self.triggers.suspend_rate} \
--resume-timeout=${self.triggers.resume_timeout} \
--suspend-timeout=${self.triggers.suspend_timeout} \
${tobool(self.triggers.no_comma_params) == true ? "--no-comma-params" : ""}
EOC
  }
}

####################
# METADATA: CONFIG #
####################

resource "google_compute_project_metadata_item" "config" {
  project = var.project_id

  key   = "${var.slurm_cluster_name}-slurm-config"
  value = jsonencode(var.metadata)
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

resource "google_compute_project_metadata_item" "compute_d" {
  project = var.project_id

  for_each = {
    for x in var.compute_d
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  key   = "${var.slurm_cluster_name}-slurm-compute-script-${each.key}"
  value = each.value.content
}

resource "google_compute_project_metadata_item" "prolog_d" {
  project = var.project_id

  for_each = {
    for x in var.prolog_d
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  key   = "${var.slurm_cluster_name}-slurm-prolog-script-${each.key}"
  value = each.value.content
}

resource "google_compute_project_metadata_item" "epilog_d" {
  project = var.project_id

  for_each = {
    for x in var.epilog_d
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
    slurm_cluster_id = local.slurm_cluster_id
  }

  lifecycle {
    create_before_destroy = true
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
  topic      = google_pubsub_topic.this[0].id

  create_topic = false

  pull_subscriptions = [
    for nodename, sa_list in local.sa_node_map
    : {
      name                    = nodename
      ack_deadline_seconds    = 60
      enable_message_ordering = true
      maximum_backoff         = "300s"
      minimum_backoff         = "30s"
    }
  ]

  subscription_labels = {
    slurm_cluster_id = local.slurm_cluster_id
  }
}

resource "google_pubsub_subscription_iam_member" "compute_pull_subscription_sa_binding_subscriber" {
  for_each = var.enable_reconfigure ? local.sa_node_map : {}

  project      = var.project_id
  subscription = each.key
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${each.value[0]}"

  depends_on = [
    module.slurm_pubsub,
  ]
}

#################
# DESTROY NODES #
#################

# Destroy all compute nodes on `terraform destroy`
module "cleanup" {
  source = "../slurm_destroy_nodes"

  slurm_cluster_id = local.slurm_cluster_id
  when_destroy     = true
}

# Destroy all compute nodes when the compute node environment changes
module "delta_critical" {
  source = "../slurm_destroy_nodes"

  count = var.enable_reconfigure ? 1 : 0

  slurm_cluster_id = local.slurm_cluster_id

  triggers = merge(
    {
      for x in var.compute_d
      : "compute_d_${replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_")}" => sha256(x.content)
    },
    {
      for x in var.prolog_d
      : "prolog_d_${replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_")}"
      => sha256(x.content)
    },
    {
      for x in var.epilog_d
      : "epilog_d_${replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_")}"
      => sha256(x.content)
    },
    {
      controller_id = null_resource.setup_hybrid.id
    },
  )
}

# Destroy all removed compute nodes when partitions change
module "delta_compute_list" {
  source = "../slurm_destroy_nodes"

  count = var.enable_reconfigure ? 1 : 0

  slurm_cluster_id = local.slurm_cluster_id
  exclude_list     = local.compute_list

  triggers = {
    compute_list = join(",", local.compute_list)
  }

  depends_on = [
    # Prevent race condition
    module.delta_critical,
  ]
}

#############################
# DESTROY RESOURCE POLICIES #
#############################

# Destroy all resource policies on `terraform destroy`
module "cleanup_resource_policies" {
  source = "../slurm_destroy_resource_policies"

  slurm_cluster_name = var.slurm_cluster_name
  when_destroy       = true
}
