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
