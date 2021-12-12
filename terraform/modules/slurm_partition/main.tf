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
  partition = {
    partition_name    = var.partition_name
    partition_conf    = var.partition_conf
    partition_nodes   = { for n in var.partition_nodes : n.node_group_name => n }
    subnetwork        = data.google_compute_subnetwork.partition_subnetwork.self_link
    zone_policy_allow = var.zone_policy_allow
    zone_policy_deny  = var.zone_policy_deny
    exclusive         = var.enable_job_exclusive
    placement_groups  = var.enable_placement_groups
    network_storage   = var.network_storage
  }
}

####################
# DATA: SUBNETWORK #
####################

data "google_compute_subnetwork" "partition_subnetwork" {
  project = var.subnetwork_project
  region  = var.region
  name    = var.subnetwork
  self_link = (
    length(regexall("/projects/([^/]*)", var.subnetwork)) > 0
    && length(regexall("/regions/([^/]*)", var.subnetwork)) > 0
    ? var.subnetwork
    : null
  )
}

##################
# DATA: TEMPLATE #
##################

data "google_compute_instance_template" "partition_template" {
  for_each = { for x in var.partition_nodes : x.node_group_name => x }

  project = (
    length(regexall("/projects/([^/]*)", each.value.instance_template)) > 0
    ? flatten(regexall("/projects/([^/]*)", each.value.instance_template))[0]
    : null
  )
  name = each.value.instance_template
}
