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
}

####################
# LOCALS: METADATA #
####################

locals {
  metadata_devel = (
    var.enable_devel == true
    ? {
      startup-script = data.local_file.startup.content
      clustereventd  = data.local_file.clustereventd.content
      clustersync    = data.local_file.clustersync.content
      setup-script   = data.local_file.setup.content
      slurm-resume   = data.local_file.resume.content
      slurm-suspend  = data.local_file.suspend.content
      slurmsync      = data.local_file.slurmsync.content
      util-script    = data.local_file.util.content
    }
    : null
  )
}

###################
# LOCALS: SCRIPTS #
###################

locals {
  compute_d = (
    var.compute_d == null
    ? abspath("${local.scripts_dir}/compute.d")
    : abspath(var.compute_d)
  )

  scripts_compute_d = {
    for script in fileset(local.compute_d, "[^.]*")
    : "custom-compute-${replace(script, "/[^a-zA-Z0-9-_]/", "_")}"
    => file("${local.compute_d}/${script}")
  }
}

########
# DATA #
########

/**
 * Verify that each node in 'var.partitions' references an existing instance
 * template as mapped by 'var.template_map'.
 */
data "google_compute_instance_template" "compute_instance_templates" {
  for_each = toset(flatten(
    [for p, o in var.partitions : [for n in o.nodes : n.template]]
  ))

  project = var.project_id
  name    = var.template_map[each.value]
}

/**
 * Verify that each partition has subnetworks that exist.
 */
data "google_compute_subnetwork" "partition_subnetworks" {
  for_each = var.partitions

  self_link = each.value.subnetwork
  project   = var.project_id
  name      = each.value.subnetwork
  region    = each.value.region
}

#################
# DATA: SCRIPTS #
#################

data "local_file" "startup" {
  filename = abspath("${local.scripts_dir}/startup.sh")
}

data "local_file" "clustereventd" {
  filename = abspath("${local.scripts_dir}/clustereventd.py")
}

data "local_file" "clustersync" {
  filename = abspath("${local.scripts_dir}/clustersync.py")
}

data "local_file" "setup" {
  filename = abspath("${local.scripts_dir}/setup.py")
}

data "local_file" "resume" {
  filename = abspath("${local.scripts_dir}/resume.py")
}

data "local_file" "suspend" {
  filename = abspath("${local.scripts_dir}/suspend.py")
}

data "local_file" "slurmsync" {
  filename = abspath("${local.scripts_dir}/slurmsync.py")
}

data "local_file" "util" {
  filename = abspath("${local.scripts_dir}/util.py")
}

##########
# RANDOM #
##########

resource "random_id" "munge_key" {
  byte_length = 256
}

resource "random_id" "jwt_key" {
  byte_length = 256
}

############
# METADATA #
############

resource "google_compute_project_metadata_item" "slurm_metadata" {
  project = var.project_id

  key = "${var.cluster_name}-slurm-metadata"
  value = jsonencode(merge(
    local.metadata_devel,
    local.scripts_compute_d,
    var.metadata_compute,
  ))
}

#################
# DESTROY NODES #
#################

module "slurm_destroy_nodes" {
  source = "../slurm_destroy_nodes"

  slurm_cluster_id = var.slurm_cluster_id
}

##########
# PUBSUB #
##########

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

resource "google_pubsub_topic" "this" {
  name = "${var.cluster_name}-slurm-events"

  schema_settings {
    schema   = google_pubsub_schema.this.id
    encoding = "JSON"
  }

  labels = {
    slurm_cluster_id = var.slurm_cluster_id
  }

  message_retention_duration = "86400s"

  lifecycle {
    create_before_destroy = true
  }
}

module "pubsub" {
  source  = "terraform-google-modules/pubsub/google"
  version = "~> 3.0"

  project_id = var.project_id
  topic      = google_pubsub_topic.this.id

  create_topic = false

  pull_subscriptions = [
    {
      name                    = "${var.cluster_name}-slurm-pull"
      ack_deadline_seconds    = 30
      maximum_backoff         = "300s"
      minimum_backoff         = "30s"
      enable_message_ordering = true
    },
  ]

  subscription_labels = {
    slurm_cluster_id = var.slurm_cluster_id
  }
}
