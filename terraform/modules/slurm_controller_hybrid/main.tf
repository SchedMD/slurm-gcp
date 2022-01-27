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
# LOCALS: SCRIPT #
##################

locals {
  setup_hybrid = abspath("${local.scripts_dir}/setup_hybrid.py")

  no_comma_params = lookup(var.cloud_parameters, "NoCommaParams", false)

  resume_rate = lookup(var.cloud_parameters, "ResumeRate", 0)

  resume_timeout = lookup(var.cloud_parameters, "ResumeTimeout", 300)

  suspend_rate = lookup(var.cloud_parameters, "SuspendRate", 0)

  suspend_timeout = lookup(var.cloud_parameters, "SuspendTimeout", 300)
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

  google_app_cred_path = (
    var.google_app_cred_path != null
    ? abspath(var.google_app_cred_path)
    : null
  )

  slurm_scripts_dir = (
    var.slurm_scripts_dir != null
    ? abspath(var.slurm_scripts_dir)
    : local.scripts_dir
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
    cluster_name = var.cluster_name
    project      = var.project_id
    etc          = local.output_dir
    scripts      = local.scripts_dir

    munge_key = local.munge_key
    jwt_key   = local.jwt_key

    pubsub_topic_id = google_pubsub_topic.this.name

    slurm_cluster_id = local.slurm_cluster_id

    network_storage       = var.network_storage
    login_network_storage = var.login_network_storage

    cloud_parameters = {
      ResumeRate      = local.resume_rate
      ResumeTimeout   = local.resume_timeout
      SuspendRate     = local.suspend_rate
      suspend_timeout = local.suspend_timeout
    }
    partitions = local.partitions

    google_app_cred_path = local.google_app_cred_path
    slurm_scripts_dir    = local.slurm_scripts_dir
    slurm_bin_dir        = local.slurm_bin_dir
    slurm_log_dir        = local.slurm_log_dir
  })
}

################
# DATA: SCRIPT #
################

data "local_file" "setup_hybrid" {
  filename = local.setup_hybrid
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
  triggers = {
    scripts_dir = local.scripts_dir
    config_dir  = local.output_dir
    config      = local_file.config_yaml.content
    config_path = local_file.config_yaml.filename
    script_path = data.local_file.setup_hybrid.filename

    no_comma_params = local.no_comma_params
    resume_rate     = local.resume_rate
    resume_timeout  = local.resume_timeout
    suspend_rate    = local.suspend_rate
    suspend_timeout = local.suspend_timeout
  }

  provisioner "local-exec" {
    working_dir = self.triggers.scripts_dir
    environment = {
      SLURM_CONFIG_YAML = self.triggers.config_path
    }
    command = <<EOC
${self.triggers.script_path} \
--ResumeRate=${self.triggers.resume_rate} \
--SuspendRate=${self.triggers.suspend_rate} \
--ResumeTimeout=${self.triggers.resume_timeout} \
--SuspendTimeout=${self.triggers.suspend_timeout} \
${tobool(self.triggers.no_comma_params) == true ? "--no-comma-params" : ""}
EOC
  }
}

####################
# METADATA: CONFIG #
####################

resource "google_compute_project_metadata_item" "config" {
  project = var.project_id

  key   = "${var.cluster_name}-slurm-config"
  value = jsonencode(var.metadata)
}

###################
# METADATA: DEVEL #
###################

module "slurm_metadata_devel" {
  source = "../_slurm_metadata_devel"

  count = var.enable_devel ? 1 : 0

  cluster_name = var.cluster_name
  project_id   = var.project_id
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

  key   = "${var.cluster_name}-slurm-compute-script-${each.key}"
  value = each.value.content
}

##################
# PUBSUB: SCHEMA #
##################

resource "google_pubsub_schema" "this" {
  name       = "${var.cluster_name}-slurm-events"
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
  name = "${var.cluster_name}-slurm-events"

  schema_settings {
    schema   = google_pubsub_schema.this.id
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

  project_id = var.project_id
  topic      = google_pubsub_topic.this.id

  create_topic = false

  pull_subscriptions = [
    for nodename in var.compute_list
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

  slurm_cluster_id = local.slurm_cluster_id

  triggers = merge(
    {
      for x in var.compute_d
      : "compute_d_${replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_")}" => sha256(x.content)
    },
    {
      controller_id = null_resource.setup_hybrid.id
    },
  )

  depends_on = [
    # Ensure compute_d metadata is updated before destroying nodes
    google_compute_project_metadata_item.compute_d,
  ]
}

# Destroy all removed compute nodes when partitions change
module "delta_compute_list" {
  source = "../slurm_destroy_nodes"

  slurm_cluster_id = local.slurm_cluster_id
  exclude_list     = var.compute_list

  triggers = {
    compute_list = join(",", var.compute_list)
  }

  depends_on = [
    # Prevent race condition
    module.delta_critical,
  ]
}
