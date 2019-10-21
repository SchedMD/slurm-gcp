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

resource "google_compute_instance" "compute_node" {
  count        = var.image_count

  name         = "${format("%s-compute-image-%02s000", var.cluster_name, count.index)}"
  machine_type = var.partitions[count.index].machine_type
  zone         = var.partitions[count.index].zone

  tags = ["compute"]

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
      type  = var.boot_disk_type
      size  = var.boot_disk_size
    }
  }

  network_interface {
    access_config {
    }

    subnetwork = var.subnet
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"

    packages = <<PACKAGES
${file("${path.module}/packages.txt")}
PACKAGES

    startup-script = <<STARTUP
${templatefile("${path.module}/startup.sh.tmpl", {
cluster_name = "${var.cluster_name}", 
controller="${var.controller_name}",
apps_dir="/apps",
nfs_apps_server = "${var.nfs_apps_server}", 
nfs_home_server = "${var.nfs_home_server}", 
})}
STARTUP
  }
}
