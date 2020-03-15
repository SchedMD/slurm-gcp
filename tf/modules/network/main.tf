#
# Copyright 2019 Google LLC
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

locals {
  tmp_list = [for part in var.partitions :
              "${join("-", slice(split("-", part.zone), 0, 2))}"
              if part.vpc_subnet == null]
  region_subnet_list = (var.subnetwork_name != null
                        ? local.tmp_list
                        : distinct(concat([var.region], local.tmp_list)))

  tmp_map = [for part in var.partitions : {
      region = "${join("-", slice(split("-", part.zone), 0, 2))}"
      subnet = (part.vpc_subnet != null
                ? part.vpc_subnet
                : "${var.cluster_name}-${join("-", slice(split("-", part.zone), 0, 2))}")
  }]
  region_router_list = distinct(
                         concat(local.tmp_map,
                                [{region = var.region
                                 subnet = (var.subnetwork_name != null
                                           ? var.subnetwork_name
                                           : "${var.cluster_name}-${var.region}")
                                }]))
}

resource "google_compute_network" "cluster_network" {
  count = (var.network_name == null &&
           var.shared_vpc_host_project == null
           ? 1
           : 0)

  name                    = "${var.cluster_name}-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "cluster_subnet" {
  count = (var.shared_vpc_host_project == null
           ? length(local.region_subnet_list)
           : 0)

  name                     = "${var.cluster_name}-${local.region_subnet_list[count.index]}"
  network                  = var.network_name != null ? var.network_name : google_compute_network.cluster_network[0].self_link
  region                   = local.region_subnet_list[count.index]
  ip_cidr_range            = "10.${count.index}.0.0/16"
  private_ip_google_access = var.private_ip_google_access
}

resource "google_compute_firewall" "cluster_ssh_firewall" {
  count = ((var.shared_vpc_host_project == null &&
            length(google_compute_network.cluster_network) > 0 &&
            (var.disable_login_public_ips == false ||
             var.disable_controller_public_ips == false ||
             var.disable_compute_public_ips == false))
           ? 1
           : 0)

  name          = "${var.cluster_name}-allow-ssh"
  network       = google_compute_network.cluster_network[0].name
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "cluster_iap_ssh_firewall" {
  count = ((var.shared_vpc_host_project == null &&
            length(google_compute_network.cluster_network) > 0 &&
            var.disable_login_public_ips &&
            var.disable_controller_public_ips &&
            var.disable_compute_public_ips)
           ? 1
           : 0)

  name          = "${var.cluster_name}-allow-iap"
  network       = google_compute_network.cluster_network[0].name
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "cluster_internal_firewall" {
  count = length(google_compute_network.cluster_network)

  name = "${var.cluster_name}-allow-internal"

  network       = google_compute_network.cluster_network[0].name
  source_ranges = ["10.0.0.0/8"]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
}

resource "google_compute_router" "cluster_router" {
  count = ((var.shared_vpc_host_project == null &&
            (var.disable_login_public_ips ||
             var.disable_controller_public_ips ||
             var.disable_compute_public_ips))
           ? length(local.region_router_list)
           : 0)

  name = "${var.cluster_name}-router"

  region  = local.region_router_list[count.index].region
  network = (var.network_name != null
             ? var.network_name
             : google_compute_network.cluster_network[0].self_link)
}

resource "google_compute_router_nat" "cluster_nat" {
  count = length(google_compute_router.cluster_router)

  depends_on = [google_compute_subnetwork.cluster_subnet]

  name = "${var.cluster_name}-nat"

  router                             = google_compute_router.cluster_router[count.index].name
  region                             = google_compute_router.cluster_router[count.index].region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = local.region_router_list[count.index].subnet
    source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
