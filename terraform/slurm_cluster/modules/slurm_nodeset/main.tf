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
  zones = setintersection(toset(data.google_compute_zones.available.names), var.zones)
}

########
# DATA #
########

data "google_compute_zones" "available" {
  project = length(regexall("projects/([^/]*)", var.subnetwork_self_link)) > 0 ? flatten(regexall("projects/([^/]*)", var.subnetwork_self_link))[0] : null
  region  = length(regexall("/regions/([^/]*)", var.subnetwork_self_link)) > 0 ? flatten(regexall("/regions/([^/]*)", var.subnetwork_self_link))[0] : null
}

###########
# NODESET #
###########

locals {
  nodeset = {
    nodeset_name           = var.nodeset_name
    node_conf              = var.node_conf
    instance_template      = var.instance_template_self_link
    node_count_dynamic_max = var.node_count_dynamic_max
    node_count_static      = var.node_count_static
    subnetwork             = var.subnetwork_self_link
    zone_target_shape      = var.zone_target_shape
    zone_policy_allow      = length(local.zones) > 0 ? setintersection(toset(data.google_compute_zones.available.names), local.zones) : toset(data.google_compute_zones.available.names)
    zone_policy_deny       = length(local.zones) > 0 ? setsubtract(toset(data.google_compute_zones.available.names), local.zones) : toset([])
    # Additional Features
    enable_placement = var.enable_placement
    enable_public_ip = var.enable_public_ip
    network_tier     = var.network_tier
  }
}

resource "null_resource" "nodeset" {
  triggers = {
    nodeset = sha256(jsonencode(local.nodeset))
  }
  lifecycle {
    precondition {
      condition     = sum([var.node_count_dynamic_max, var.node_count_static]) > 0
      error_message = "Sum of node_count_dynamic_max and node_count_static must be > 0."
    }
  }
}
