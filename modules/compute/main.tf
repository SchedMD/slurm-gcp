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
  name         = "${var.cluster_name}-compute-image-${format("%05d", var.partition_id)}"
  machine_type = var.compute_machine_type
  zone         = var.zone

  tags = ["compute"]

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
      type  = var.login_boot_disk_type
      size  = var.login_boot_disk_size
    }
  }

  network_interface {
    access_config {
    }

    subnetwork = var.network
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"

    startup-script = <<STARTUP
${templatefile("${path.module}/startup-script.tmpl", {
cluster_name = "${var.cluster_name}", 
project = "${var.project}", 
zone = "${var.zone}", 
instance_type = "compute",
munge_key = "${var.munge_key}", 
slurm_version ="${var.slurm_version}", 
def_slurm_acct = "${var.default_account}", 
def_slurm_users = "${var.default_users}", 
external_compute_ips = "${var.external_compute_ips}", 
nfs_apps_server = "${var.nfs_apps_server}", 
nfs_home_server = "${var.nfs_home_server}", 
controller_secondary_disk = "${var.controller_secondary_disk}", 
suspend_time = "${var.suspend_time}", 
partitions = "${var.partitions}"
})}
STARTUP
  }
}
