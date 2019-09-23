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

resource "google_compute_instance" "login_node" {
  count        = var.node_count
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

  network_interface {
    access_config {
    }

    subnetwork = var.network
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "FALSE"
    sshKeys = "${var.deploy_user}:${file("${var.deploy_key_path}.pub")}"
  }

  provisioner "remote-exec" {
    inline = [ 
      "sudo yum update -y",
      "[ ! -d /apps ] && sudo mkdir /apps",
      "[ ! -d /var/log/slurm ] && sudo mkdir /var/log/slurm",
      "[ ! -d /tmp/slurm ] && mkdir /tmp/slurm"
    ]
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.login_node[0].network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }

  provisioner "file" {
    source      = "${path.module}/packages.txt"
    destination = "/tmp/slurm/packages.txt"
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.login_node[0].network_interface[0].access_config[0].nat_ip
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
      host = google_compute_instance.login_node[0].network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }

  provisioner "file" {
    source      = "${path.module}/../shared/functions.sh"
    destination = "/tmp/slurm/functions.sh"
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.login_node[0].network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }

  provisioner "file" {
    source      = "${path.module}/configure.sh"
    destination = "/tmp/slurm/configure.sh"
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.login_node[0].network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod a+x /tmp/slurm/configure.sh",
      "(cd /tmp/slurm; sudo ./configure.sh ${var.nfs_apps_server})"
    ]
    connection {
      private_key = "${file(var.deploy_key_path)}"
      host = google_compute_instance.login_node[0].network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "${var.deploy_user}"
    }
  }
}
