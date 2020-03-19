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
  compute_node_prefix = "${var.cluster_name}-compute"
}

resource "google_compute_disk" "secondary" {
  count = var.secondary_disk ? 1 : 0

  name = "secondary"
  size = var.secondary_disk_size
  type = var.secondary_disk_type
  zone = var.zone
}

resource "google_compute_instance" "controller_node" {
  depends_on = [var.subnet_depend]

  name         = local.controller_name
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["controller"]

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
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
    cloudsql                     = var.cloudsql
    cluster_name                 = var.cluster_name,
    compute_node_prefix          = local.compute_node_prefix,
    compute_node_scopes          = var.compute_node_scopes,
    compute_node_service_account = var.compute_node_service_account,
    controller_secondary_disk    = var.secondary_disk,
    external_compute_ips         = !var.disable_compute_public_ips,
    login_network_storage        = var.login_network_storage,
    login_node_count             = var.login_node_count
    munge_key                    = var.munge_key,
    network_storage              = var.network_storage,
    ompi_version                 = var.ompi_version,
    partitions                   = var.partitions,
    project                      = var.project,
    region                       = var.region,
    shared_vpc_host_project      = var.shared_vpc_host_project,
    slurm_version                = var.slurm_version,
    suspend_time                 = var.suspend_time,
    vpc_subnet                   = var.subnetwork_name,
    zone                         = var.zone,
})}
EOF

    setup_script = <<EOF
${file("${path.module}/../../../scripts/setup.py")}
EOF

    slurm_resume = <<EOF
${file("${path.module}/../../../scripts/resume.py")}
EOF

    slurm_suspend = <<EOF
${file("${path.module}/../../../scripts/suspend.py")}
EOF

    slurmsync = <<EOF
${file("${path.module}/../../../scripts/slurmsync.py")}
EOF

    slurmsync = <<EOF
${file("${path.module}/../../../scripts/slurmsync.py")}
EOF

    custom-compute-install = <<EOF
${file("${path.module}/../../../scripts/custom-compute-install")}
EOF

    custom-controller-install = <<EOF
${file("${path.module}/../../../scripts/custom-controller-install")}
EOF

    compute-shutdown = <<EOF
${file("${path.module}/../../../scripts/compute-shutdown")}
EOF

    slurm_conf_tpl = <<EOF
${file("${path.module}/../../../etc/slurm.conf.tpl")}
EOF

    slurmdbd_conf_tpl = <<EOF
${file("${path.module}/../../../etc/slurmdbd.conf.tpl")}
EOF

    cgroup_conf_tpl = <<EOF
${file("${path.module}/../../../etc/cgroup.conf.tpl")}
EOF

    fluentd_conf_tpl = <<EOF
${file("${path.module}/../../../etc/controller-fluentd.conf.tpl")}
EOF
  }
}
