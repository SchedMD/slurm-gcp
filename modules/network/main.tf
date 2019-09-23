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

resource "google_compute_network" "cluster_network" {
  name                    = "${var.cluster_name}-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "cluster_subnet" {
  name                     = "${var.cluster_name}-subnet"
  network                  = "${google_compute_network.cluster_network.self_link}"
  region                   = var.region
  ip_cidr_range            = var.cluster_network_cidr_range
  private_ip_google_access = var.private_ip_google_access
}

resource "google_compute_firewall" "cluster_ssh_firewall" {
  name          = "${var.cluster_name}-allow-ssh"
  network       = google_compute_network.cluster_network.name
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "cluster_internal_firewall" {
  name          = "${var.cluster_name}-allow-internal"
  network       = google_compute_network.cluster_network.name
  source_ranges = [var.cluster_network_cidr_range]

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
