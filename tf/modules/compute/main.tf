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

resource "google_compute_instance" "compute_image" {
  count        = length(var.partitions)
  name         = "${local.compute_node_prefix}-${count.index}-image"
  machine_type = var.compute_image_machine_type
  zone         = var.zone

  tags = ["compute"]

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
      type  = var.compute_image_disk_type
      size  = var.compute_image_disk_size_gb
    }
  }

  network_interface {
    dynamic "access_config" {
      for_each = var.disable_compute_public_ips == true ? [] : [1]
      content {}
    }

    subnetwork = var.subnet
  }

  service_account {
    email  = "default"
    scopes = ["cloud-platform"]
  }

  metadata = {
    terraform      = "TRUE"
    enable-oslogin = "TRUE"

    startup-script = <<EOF
${file("${path.module}/../../../scripts/startup.sh")}
EOF

    util_script = <<EOF
${file("${path.module}/../../../scripts/util.py")}
EOF

    config = <<EOF
${jsonencode({
    cluster_name              = var.cluster_name,
    cluster_subnet            = var.subnet,
    compute_node_prefix       = local.compute_node_prefix,
    controller_secondary_disk = var.controller_secondary_disk,
    munge_key                 = var.munge_key,
    ompi_version              = var.ompi_version
    network_storage           = var.network_storage
    partitions                = var.partitions
    zone                      = var.zone
})}
EOF

    setup_script = <<EOF
${file("${path.module}/../../../scripts/setup.py")}
EOF

  }
}
