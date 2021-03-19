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
}

data "google_compute_default_service_account" "default" {}

resource "google_compute_instance" "login_node" {
  count = var.instance_template == null ? var.node_count : 0

  depends_on = [var.subnet_depend]

  name         = "${var.cluster_name}-login${count.index}"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["login"]

  boot_disk {
    initialize_params {
      image = var.image
      type  = var.boot_disk_type
      size  = var.boot_disk_size
    }
  }

  labels = var.labels

  network_interface {
    dynamic "access_config" {
      for_each = var.disable_login_public_ips == true ? [] : [1]
      content {}
    }

    # Subnet order:
    # 1. shared_vpc_host_project / var.subnetwork_name
    #   a. subnetwork_project isn't set when shared_vpc_host_project is null
    # 2. var.project / var.subnetwork_name
    # 3. var.project / {cluster_name}-{region}
    subnetwork = (var.subnetwork_name != null
      ? var.subnetwork_name
    : "${var.cluster_name}-${var.region}")

    subnetwork_project = var.shared_vpc_host_project
  }

  service_account {
    email  = var.service_account == null ? data.google_compute_default_service_account.default.email : var.service_account
    scopes = var.scopes
  }

  metadata_startup_script = file("${path.module}/../../../scripts/startup.sh")

  metadata = {
    enable-oslogin = "TRUE"
    VmDnsSetting   = "GlobalOnly"

    util-script = file("${path.module}/../../../scripts/util.py")

    config = jsonencode({
      cluster_name              = var.cluster_name
      controller_secondary_disk = var.controller_secondary_disk
      munge_key                 = var.munge_key
      login_network_storage     = var.login_network_storage
      network_storage           = var.network_storage
    })

    setup-script = file("${path.module}/../../../scripts/setup.py")
  }
}


resource "google_compute_instance_from_template" "login_node" {
  count = var.instance_template != null ? var.node_count : 0

  source_instance_template = var.instance_template

  depends_on = [var.subnet_depend]

  name         = "${var.cluster_name}-login${count.index}"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["login"]

  dynamic "boot_disk" {
    for_each = var.image != null && var.boot_disk_type != null && var.boot_disk_size != null ? [1] : []
    content {
      auto_delete = true
      initialize_params {
        image = var.image
        type  = var.boot_disk_type
        size  = var.boot_disk_size
      }
    }
  }

  labels = var.labels

  network_interface {
    dynamic "access_config" {
      for_each = var.disable_login_public_ips == true ? [] : [1]
      content {}
    }

    # Subnet order:
    # 1. shared_vpc_host_project / var.subnetwork_name
    #   a. subnetwork_project isn't set when shared_vpc_host_project is null
    # 2. var.project / var.subnetwork_name
    # 3. var.project / {cluster_name}-{region}
    subnetwork = (var.subnetwork_name != null
      ? var.subnetwork_name
    : "${var.cluster_name}-${var.region}")

    subnetwork_project = var.shared_vpc_host_project
  }

  service_account {
    email  = var.service_account == null ? data.google_compute_default_service_account.default.email : var.service_account
    scopes = var.scopes
  }

  metadata_startup_script = file("${path.module}/../../../scripts/startup.sh")

  metadata = {
    enable-oslogin = "TRUE"
    VmDnsSetting   = "GlobalOnly"

    util-script = file("${path.module}/../../../scripts/util.py")

    config = jsonencode({
      cluster_name              = var.cluster_name
      controller_secondary_disk = var.controller_secondary_disk
      munge_key                 = var.munge_key
      login_network_storage     = var.login_network_storage
      network_storage           = var.network_storage
    })

    setup-script = file("${path.module}/../../../scripts/setup.py")
  }
}
