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

resource "google_compute_instance" "controller_node" {
  name         = "${var.cluster_name}-controller"
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

    subnetwork = var.network
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    sshKeys = "${var.deploy_user}:${file("${var.deploy_key_path}.pub")}"
#     enable-oslogin = "TRUE"

#     startup-script = <<STARTUP
# ${templatefile("${path.module}/startup-script.tmpl", {
# cluster_name = "${var.cluster_name}", 
# project = "${var.project}", 
# zone = "${var.zone}", 
# instance_type = "controller",
# munge_key = "${var.munge_key}", 
# slurm_version ="${var.slurm_version}", 
# def_slurm_acct = "${var.default_account}", 
# def_slurm_users = "${var.default_users}", 
# external_compute_ips = "${var.external_compute_ips}", 
# nfs_apps_server = "${var.nfs_apps_server}", 
# nfs_home_server = "${var.nfs_home_server}", 
# controller_secondary_disk = "${var.controller_secondary_disk}", 
# suspend_time = "${var.suspend_time}", 
# partitions = "${var.partitions}"
# })}
# STARTUP
# 
#     startup-script-compute = <<COMPUTESTARTUP
# ${templatefile("${path.module}/startup-script.tmpl", {
# cluster_name = "${var.cluster_name}", 
# project = "${var.project}", 
# zone = "${var.zone}", 
# instance_type = "compute",
# munge_key = "${var.munge_key}", 
# slurm_version ="${var.slurm_version}", 
# def_slurm_acct = "${var.default_account}", 
# def_slurm_users = "${var.default_users}", 
# external_compute_ips = "${var.external_compute_ips}", 
# nfs_apps_server = "${var.nfs_apps_server}", 
# nfs_home_server = "${var.nfs_home_server}", 
# controller_secondary_disk = "${var.controller_secondary_disk}", 
# suspend_time = "${var.suspend_time}", 
# partitions = "${var.partitions}"
# })}
# COMPUTESTARTUP

    slurm_resume = <<RESUME
${file("${path.module}/resume.py")}
RESUME

    slurm_suspend = <<SUSPEND
${file("${path.module}/suspend.py")}
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

  provisioner "remote-exec" {
    inline = [ 
      "sudo yum update -y",
      "[ ! -d /var/log/slurm ] && sudo mkdir /var/log/slurm",
      "[ ! -d /tmp/slurm ] && mkdir /tmp/slurm"
    ]
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }

  provisioner "file" {
    source      = "${path.module}/packages.txt"
    destination = "/tmp/slurm/packages.txt"
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }

  provisioner "remote-exec" {
    inline = [ 
      "sudo yum -y install $(cat /tmp/slurm/packages.txt)"
    ]
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }

  provisioner "file" {
    source      = "${path.module}/../shared/functions.sh"
    destination = "/tmp/slurm/functions.sh"
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }

  provisioner "file" {
    source      = "${path.module}/configure.sh"
    destination = "/tmp/slurm/configure.sh"
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }

  provisioner "file" {
    destination = "/tmp/slurm/slurm.conf"
    content     = module.slurm_conf.content
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }

  provisioner "file" {
    destination = "/tmp/slurm/slurmdbd.conf"
    content     = "${templatefile("${path.module}/slurmdbd.conf.tmpl",{
cluster_name=var.cluster_name,
control_machine="${var.cluster_name}-controller",
apps_dir="/apps"
})}"
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }

  provisioner "file" {
    source      = "${path.module}/cgroup.conf"
    destination = "/tmp/slurm/cgroup.conf"
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }

  provisioner "file" {
    source      = "${path.module}/suspend.py"
    destination = "/tmp/slurm/suspend.py"
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }

  provisioner "file" {
    source      = "${path.module}/resume.py"
    destination = "/tmp/slurm/resume.py"
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }

  provisioner "file" {
    source      = "${path.module}/slurm-gcp-sync.py"
    destination = "/tmp/slurm/slurm-gcp-sync.py"
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /apps/slurm/src",
      "sudo chmod a+x /tmp/slurm/configure.sh",
      "(cd /tmp/slurm; sudo ./configure.sh ${var.slurm_version} | systemd-cat -t configureslurm -p info)"
    ]
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /apps/slurm/scripts",
      "sudo mv /tmp/slurm/*.py /apps/slurm/scripts",
      "sudo chmod -R u=rwx,go=rx /apps/slurm/scripts"
    ]
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/slurm/slurmdbd.conf /apps/slurm/current/etc",
      "sudo mv /tmp/slurm/cgroup.conf /apps/slurm/current/etc",
      "sudo touch /apps/slurm/current/etc/cgroup_allowed_devices_file.conf"
    ]
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }
}
