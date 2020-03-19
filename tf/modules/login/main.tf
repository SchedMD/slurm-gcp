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
  compute_node_prefix = "${var.cluster_name}-compute"
}

resource "google_compute_instance" "login_node" {
  count = var.node_count

  depends_on = [var.subnet_depend]

  name         = "${var.cluster_name}-login${count.index}"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["login"]

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
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
    email  = var.service_account
    scopes = var.scopes
  }

  metadata = {
    terraform      = "TRUE"
    enable-oslogin = "TRUE"
    VmDnsSetting   = "GlobalOnly"

    startup-script = <<EOF
${file("${path.module}/../../../scripts/startup.sh")}
EOF

    util_script = <<EOF
${file("${path.module}/../../../scripts/util.py")}
EOF

    config = <<EOF
${jsonencode({
    cluster_name              = var.cluster_name,
    compute_node_prefix       = local.compute_node_prefix,
    controller_secondary_disk = var.controller_secondary_disk,
    munge_key                 = var.munge_key,
    ompi_version              = var.ompi_version
    login_network_storage     = var.login_network_storage
    network_storage           = var.network_storage
})}
EOF

    setup_script = <<EOF
${file("${path.module}/../../../scripts/setup.py")}
EOF

  }
}
