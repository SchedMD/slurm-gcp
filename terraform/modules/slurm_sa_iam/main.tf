/**
 * Copyright 2022 SchedMD LLC
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
  roles = {
    controller = [
      "roles/compute.instanceAdmin",
      "roles/iam.serviceAccountUser",
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter",
      "roles/pubsub.publisher",
      "roles/pubsub.subscriber",
      "roles/secretmanager.secretAccessor",
      "roles/bigquery.dataEditor"
    ]
    compute = [
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter",
      "roles/pubsub.subscriber",
      "roles/secretmanager.secretAccessor",
    ]
    login = [
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter",
      "roles/secretmanager.secretAccessor",
    ]
  }

  account = {
    "${var.account_type}" = local.roles[var.account_type]
  }
}

###################
# SERVICE ACCOUNT #
###################

resource "google_service_account" "slurm_service_account" {
  for_each = var.account_type != null ? local.account : local.roles

  account_id   = "${var.slurm_cluster_name}-${each.key}"
  display_name = "${var.slurm_cluster_name}-${each.key} Slurm SA IAM"
  project      = var.project_id
}

#######
# IAM #
#######

module "slurm_member_roles" {
  source  = "terraform-google-modules/iam/google//modules/member_iam"
  version = "~> 7.0"

  for_each = var.account_type != null ? local.account : local.roles

  service_account_address = google_service_account.slurm_service_account[each.key].email
  prefix                  = "serviceAccount"
  project_id              = var.project_id
  project_roles           = each.value
}
