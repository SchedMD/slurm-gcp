provider "google" {
  project = var.project
  region  = var.region
}

resource "google_compute_instance" "cluster_node" {
  name         = "${var.cluster_name}-controller"
  machine_type = var.controller_machine_type
  zone         = var.zone

  tags = ["controller"]

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
      size  = 64
    }
  }

  // Local SSD disk
  scratch_disk {
  }

  network_interface {
    access_config {
    }

    network = var.network
  }

  service_account {
    scopes = ["cloud-platform", "userinfo-email", "compute-ro", "storage-ro"]
  }
}

resource "google_compute_instance" "login_node" {
  count        = 3
  name         = "${var.cluster_name}-login${count.index}"
  machine_type = var.login_machine_type
  zone         = var.zone

  tags = ["login"]

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
      size  = 64
    }
  }

  // Local SSD disk
  scratch_disk {
  }

  network_interface {
    access_config {
    }

    network = var.network
  }

  service_account {
    scopes = ["cloud-platform", "userinfo-email", "compute-ro", "storage-ro"]
  }
}

