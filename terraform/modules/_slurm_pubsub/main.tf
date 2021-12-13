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
# SCHEMA #
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

#########
# TOPIC #
#########

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

##########
# PUBSUB #
##########

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
