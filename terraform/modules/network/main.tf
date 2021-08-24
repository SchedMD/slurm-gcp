# Copyright 2021 SchedMD LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

###########
# NETWORK #
###########

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 3.0"

  project_id   = var.project_id
  network_name = "${var.cluster_name}-vpc"
  routing_mode = "GLOBAL"

  subnets = [
    for index, region in var.subnets_regions : {
      subnet_name   = "${var.cluster_name}-subnet"
      subnet_ip     = "10.${index}.0.0/24"
      subnet_region = region

      subnet_private_access = true
      subnet_flow_logs      = true
    }
  ]

  firewall_rules = [
    {
      name      = "${var.cluster_name}-allow-ssh-ingress"
      direction = "INGRESS"
      ranges    = ["0.0.0.0/0"]
      allow = [
        {
          protocol = "tcp"
          ports    = ["22"]
        },
      ]
      deny = []
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
    {
      name      = "${var.cluster_name}-allow-iap-ingress"
      direction = "INGRESS"
      ranges    = ["35.235.240.0/20"]
      allow = [
        {
          protocol = "tcp"
          ports    = ["22", "8642", "6842"]
        },
      ]
      deny = []
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
    {
      name      = "${var.cluster_name}-allow-internal-ingress"
      direction = "INGRESS"
      ranges    = ["10.0.0.0/8"]
      allow = [
        {
          protocol = "icmp"
          ports    = []
        },
        {
          protocol = "tcp"
          ports    = ["0-65535"]
        },
        {
          protocol = "udp"
          ports    = ["0-65535"]
        },
      ]
      deny = []
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
  ]
}

##########
# ROUTER #
##########

module "cluster_router" {
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 1.0"

  for_each = module.vpc.subnets

  name    = "${var.cluster_name}-${each.value.region}-router"
  project = var.project_id
  region  = each.value.region
  network = module.vpc.network.network_id
}

#######
# NAT #
#######

module "cluster_nat" {
  source  = "terraform-google-modules/cloud-nat/google"
  version = "~> 2.0"

  for_each = module.cluster_router

  name       = "${var.cluster_name}-${each.value.router.region}-nat"
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
