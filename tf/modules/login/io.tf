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

variable "network" {
  description = "Compute Platform network the Slurm cluster nodes will be connected to"
  default     = "default"
}

variable "disable_login_public_ips" {
  description = "If set to true, create Cloud NAT gateway and enable IAP FW rules"
  default     = false
}

variable "subnet" {
  description = "Compute Platform subnetwork the Slurm cluster nodes will be connected to"
  default     = "default"
}

variable "zone" {
  description = "Compute Platform zone where the notebook server will be located"
  default     = "us-central1-b"
}

variable "cluster_name" {
  description = "Name of the Slurm cluster"
}

variable "controller_name" {
  description = "FQDN or IP address of the controller node"
}

variable "machine_type" {
  description = "Compute Platform machine type to use in login node creation"
  default     = "n1-standard-2"
}

variable "node_count" {
  description = "The number of cluster login nodes to create"
  default     = 1
}

variable "boot_disk_type" {
  description = "Type of boot disk to create for the cluster login node"
  default     = "pd-ssd"
}

variable "boot_disk_size" {
  description = "Size of boot disk to create for the cluster login node"
  default     = 16
}

variable "apps_dir" {
  description = "Slurm cluster applications directory"
  default     = "/apps"
}

variable "nfs_apps_server" {
  description = "IP address of the NFS server hosting the apps directory"
  default     = ""
}

variable "nfs_home_server" {
  description = "IP address of the NFS server hosting the home directory"
  default     = ""
}

output "instance_network_ips" {
  value = [ "${google_compute_instance.login_node.*.network_interface.0.network_ip}" ]
}
