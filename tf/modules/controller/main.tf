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
  controller_name = "${var.cluster_name}-controller"
  config = jsonencode({
    cloudsql                     = var.cloudsql
    cluster_name                 = var.cluster_name
    compute_node_scopes          = var.compute_node_scopes
    compute_node_service_account = var.compute_node_service_account == null ? data.google_compute_default_service_account.default.email : var.compute_node_service_account
    controller_secondary_disk    = var.secondary_disk
    external_compute_ips         = !var.disable_compute_public_ips
    login_network_storage        = var.login_network_storage
    login_node_count             = var.login_node_count
    munge_key                    = var.munge_key
    jwt_key                      = var.jwt_key
    network_storage              = var.network_storage
    partitions                   = var.partitions
    project                      = var.project
    region                       = var.region
    shared_vpc_host_project      = var.shared_vpc_host_project
    suspend_time                 = var.suspend_time
    vpc_subnet                   = var.subnetwork_name
    zone                         = var.zone
  })
}

resource "google_compute_disk" "secondary" {
  count = var.secondary_disk ? 1 : 0

  name = "secondary"
  size = var.secondary_disk_size
  type = var.secondary_disk_type
  zone = var.zone
}

data "google_compute_default_service_account" "default" {}

resource "google_compute_instance" "controller_node" {
  count = var.instance_template == null ? 1 : 0

  depends_on = [var.subnet_depend]

  name         = local.controller_name
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["controller"]

  boot_disk {
    initialize_params {
      image = var.image
      type  = var.boot_disk_type
      size  = var.boot_disk_size
    }
  }

  dynamic "attached_disk" {
    for_each = google_compute_disk.secondary
    content {
      source = google_compute_disk.secondary[0].self_link
    }
  }

  labels = var.labels

  network_interface {
    dynamic "access_config" {
      for_each = var.disable_controller_public_ips == true ? [] : [1]
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

    config = local.config
    cgroup_conf_tpl           = file("${path.module}/../../../etc/cgroup.conf.tpl")
    custom-compute-install    = file("${path.module}/../../../scripts/custom-compute-install")
    custom-controller-install = file("${path.module}/../../../scripts/custom-controller-install")
    setup-script              = file("${path.module}/../../../scripts/setup.py")
    slurm-resume              = file("${path.module}/../../../scripts/resume.py")
    slurm-suspend             = file("${path.module}/../../../scripts/suspend.py")
    slurm_conf_tpl            = file("${path.module}/../../../etc/slurm.conf.tpl")
    slurmdbd_conf_tpl         = file("${path.module}/../../../etc/slurmdbd.conf.tpl")
    slurmsync                 = file("${path.module}/../../../scripts/slurmsync.py")
    util-script               = file("${path.module}/../../../scripts/util.py")
  }
}

resource "google_compute_instance_from_template" "controller_node" {
  count = var.instance_template != null ? 1 : 0

  source_instance_template = var.instance_template

  depends_on = [var.subnet_depend]

  name         = local.controller_name
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["controller"]

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

  dynamic "attached_disk" {
    for_each = google_compute_disk.secondary
    content {
      source = google_compute_disk.secondary[0].self_link
    }
  }

  labels = var.labels

  network_interface {
    dynamic "access_config" {
      for_each = var.disable_controller_public_ips == true ? [] : [1]
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
	config = local.config

    cgroup_conf_tpl           = file("${path.module}/../../../etc/cgroup.conf.tpl")
    custom-compute-install    = file("${path.module}/../../../scripts/custom-compute-install")
    custom-controller-install = file("${path.module}/../../../scripts/custom-controller-install")
    setup-script              = file("${path.module}/../../../scripts/setup.py")
    slurm-resume              = file("${path.module}/../../../scripts/resume.py")
    slurm-suspend             = file("${path.module}/../../../scripts/suspend.py")
    slurm_conf_tpl            = file("${path.module}/../../../etc/slurm.conf.tpl")
    slurmdbd_conf_tpl         = file("${path.module}/../../../etc/slurmdbd.conf.tpl")
    slurmsync                 = file("${path.module}/../../../scripts/slurmsync.py")
    util-script               = file("${path.module}/../../../scripts/util.py")
  }
}
