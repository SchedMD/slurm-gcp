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
  static_list = flatten([
    for pid in range(length(var.partitions)) : [
      for n in range(var.partitions[pid].static_node_count) : {
        name           = "${var.cluster_name}-compute-${pid}-${n}"
        boot_disk_size = var.partitions[pid].compute_disk_size_gb
        boot_disk_type = var.partitions[pid].compute_disk_type
        image          = var.partitions[pid].image
        labels         = var.partitions[pid].compute_labels
        machine_type   = var.partitions[pid].machine_type
        sa_email       = var.service_account
        sa_scopes      = var.scopes
        template       = var.partitions[pid].instance_template
        zone           = var.partitions[pid].zone
        gpu_type       = var.partitions[pid].gpu_type
        gpu_count      = var.partitions[pid].gpu_count
        subnet = (var.partitions[pid].vpc_subnet != null
          ? var.partitions[pid].vpc_subnet
        : "${var.cluster_name}-${join("-", slice(split("-", var.partitions[pid].zone), 0, 2))}")
      }
    ]
  ])

  compute_map = {
    for static in local.static_list : static.name => static if static.template == null
  }
  template_map = {
    for static in local.static_list : static.name => static if static.template != null
  }
}


resource "google_compute_instance" "compute_node" {
  for_each = local.compute_map

  depends_on = [var.subnet_depend]

  name         = each.value.name
  machine_type = each.value.machine_type
  zone         = each.value.zone

  tags = ["compute"]

  boot_disk {
    initialize_params {
      image = each.value.image
      type  = each.value.boot_disk_type
      size  = each.value.boot_disk_size
    }
  }

  labels = each.value.labels

  guest_accelerator {
    count = each.value.gpu_count

    type = each.value.gpu_type != null ? each.value.gpu_type : ""
  }

  network_interface {
    dynamic "access_config" {
      for_each = var.disable_compute_public_ips == true ? [] : [1]
      content {}
    }

    # Subnet order:
    # 1. shared_vpc_host_project / var.subnetwork_name|part.vpc_subnet
    #   a. subnetwork_project isn't set when shared_vpc_host_project is null
    # 2. var.project / part.vpc_subnet
    # 3. var.project / {cluster_name}-{region}
    subnetwork         = each.value.subnet
    subnetwork_project = var.shared_vpc_host_project
  }

  dynamic "scheduling" {
    for_each = each.value.gpu_count > 0 ? [1] : [0]
    content {
      on_host_maintenance = "TERMINATE"
    }
  }

  service_account {
    email  = each.value.sa_email
    scopes = each.value.sa_scopes
  }

  metadata_startup_script = file("${path.module}/../../../scripts/startup.sh")

  metadata = {
    enable-oslogin = "TRUE"
    VmDnsSetting   = "GlobalOnly"

    config = jsonencode({
      cluster_name              = var.cluster_name,
      controller_secondary_disk = var.controller_secondary_disk,
      munge_key                 = var.munge_key,
      network_storage           = var.network_storage
      partitions                = var.partitions
      zone                      = var.zone
    })

    setup-script     = file("${path.module}/../../../scripts/setup.py")
    util-script      = file("${path.module}/../../../scripts/util.py")
  }
}

resource "google_compute_instance_from_template" "compute_node" {
  for_each = local.template_map

  source_instance_template = each.value.template

  depends_on = [var.subnet_depend]

  name         = each.value.name
  machine_type = each.value.machine_type
  zone         = each.value.zone

  tags = ["compute"]

  dynamic "boot_disk" {
    for_each = each.value.image != null && each.value.boot_disk_type != null && each.value.boot_disk_size != null ? [1] : []
    content {
      auto_delete = true
      initialize_params {
        image = each.value.image
        type  = each.value.boot_disk_type
        size  = each.value.boot_disk_size
      }
    }
  }

  labels = each.value.labels

  guest_accelerator {
    count = each.value.gpu_count

    type = each.value.gpu_type != null ? each.value.gpu_type : ""
  }

  network_interface {
    dynamic "access_config" {
      for_each = var.disable_compute_public_ips == true ? [] : [1]
      content {}
    }

    # Subnet order:
    # 1. shared_vpc_host_project / var.subnetwork_name|part.vpc_subnet
    #   a. subnetwork_project isn't set when shared_vpc_host_project is null
    # 2. var.project / part.vpc_subnet
    # 3. var.project / {cluster_name}-{region}
    subnetwork         = each.value.subnet
    subnetwork_project = var.shared_vpc_host_project
  }

  dynamic "scheduling" {
    for_each = each.value.gpu_count > 0 ? [1] : [0]
    content {
      on_host_maintenance = "TERMINATE"
    }
  }

  service_account {
    email  = each.value.sa_email
    scopes = each.value.sa_scopes
  }

  metadata_startup_script = file("${path.module}/../../../scripts/startup.sh")

  metadata = {
    enable-oslogin = "TRUE"
    VmDnsSetting   = "GlobalOnly"

    config = jsonencode({
      cluster_name              = var.cluster_name,
      controller_secondary_disk = var.controller_secondary_disk,
      munge_key                 = var.munge_key,
      network_storage           = var.network_storage
      partitions                = var.partitions
      zone                      = var.zone
    })

    setup-script     = file("${path.module}/../../../scripts/setup.py")
    util-script      = file("${path.module}/../../../scripts/util.py")
  }
}
