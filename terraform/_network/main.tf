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

###########
# NETWORK #
###########

module "network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 4.0"

  project_id                             = var.project_id
  description                            = var.description
  network_name                           = var.network_name
  routing_mode                           = var.routing_mode
  shared_vpc_host                        = var.shared_vpc_host
  mtu                                    = var.mtu
  auto_create_subnetworks                = var.auto_create_subnetworks
  delete_default_internet_gateway_routes = var.delete_default_internet_gateway_routes

  subnets          = var.subnets
  secondary_ranges = var.secondary_ranges

  routes = var.routes

  firewall_rules = var.firewall_rules
}

##########
# ROUTER #
##########

module "router" {
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 1.0"

  for_each = module.network.subnets

  name    = "${each.value.name}-router"
  project = var.project_id
  region  = each.value.region
  network = module.network.network.network_id
}

#######
# NAT #
#######

module "nat" {
  source  = "terraform-google-modules/cloud-nat/google"
  version = "~> 2.0"

  for_each = module.router

  name       = "${var.network_name}-nat"
  project_id = var.project_id
  region     = each.value.router.region
  router     = each.value.router.name

  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetworks = [
    {
      name                     = each.key
      source_ip_ranges_to_nat  = ["PRIMARY_IP_RANGE"]
      secondary_ip_range_names = ["LIST_OF_SECONDARY_IP_RANGES"]
    },
  ]

  log_config_filter = "ERRORS_ONLY"
}
