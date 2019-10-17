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

module "slurm_conf" {
  source = "../slurm_conf"

  cluster_name = var.cluster_name
  partitions   = var.partitions
}

locals {
  controller_name = "${var.cluster_name}-controller"
}

resource "google_compute_instance" "controller_node" {
  name         = local.controller_name
  machine_type = var.controller_machine_type
  zone         = var.zone

  tags = ["controller"]

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
      type  = var.controller_boot_disk_type
      size  = var.controller_boot_disk_size
    }
  }

  // Local SSD disk
  scratch_disk {
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

    startup-script = <<STARTUP
${templatefile("${path.module}/startup.sh.tmpl", {
apps_dir="${var.apps_dir}",
cluster_name="${var.cluster_name}",
default_account="${var.default_account}",
default_partition="${var.default_partition}",
nfs_apps_server="${var.nfs_apps_server}",
nfs_home_server="${var.nfs_home_server}",
slurm_version="${var.slurm_version}"
users="${var.users}"
})}
STARTUP

    startup-script-compute = <<COMPUTESTARTUP
${templatefile("${path.module}/../compute/startup.sh.tmpl", {
cluster_name = "${var.cluster_name}", 
controller=local.controller_name,
apps_dir="/apps",
nfs_apps_server = "${var.nfs_apps_server}", 
nfs_home_server = "${var.nfs_home_server}", 
})}
COMPUTESTARTUP
 
    cgroup_conf = <<CGROUPCONF
${file("${path.module}/cgroup.conf")}
CGROUPCONF

    packages = <<PACKAGES
${file("${path.module}/packages.txt")}
PACKAGES

    slurm_conf = module.slurm_conf.content

    slurmdbd_conf = <<SLURMDBDCONF
${templatefile("${path.module}/slurmdbd.conf.tmpl", {
apps_dir="${var.apps_dir}"
control_machine=local.controller_name
})}
SLURMDBDCONF

    slurm-resume = <<RESUME
${templatefile("${path.module}/resume.py", {
cluster_name = "${var.cluster_name}",
project = "${var.project}",
region = "${var.region}",
partitions = "${jsonencode(var.partitions)}"
subnet = "${var.subnet}"
})}
RESUME

    slurm-suspend = <<SUSPEND
${templatefile("${path.module}/suspend.py", {
project = "${var.project}",
partitions = "${jsonencode(var.partitions)}"
})}
SUSPEND

    slurm-gcp-sync = <<GCPSYNC
${file("${path.module}/slurm-gcp-sync.py")}
GCPSYNC

    custom-compute-install = <<CUSTOMCOMPUTE
${file("${path.module}/custom-compute-install")}
CUSTOMCOMPUTE

    custom-controller-install = <<CUSTOMCONTROLLER
${file("${path.module}/custom-controller-install")}
CUSTOMCONTROLLER
  }
}
