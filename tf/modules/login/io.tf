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

variable "boot_disk_size" {
  description = "Size of boot disk to create for the cluster login node"
  default     = 20
}

variable "boot_disk_type" {
  description = "Type of boot disk to create for the cluster login node"
  default     = "pd-standard"
}

variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

variable "controller_name" {
  description = "FQDN or IP address of the controller node"
  type        = string
}

variable "controller_secondary_disk" {
  description = "Create secondary disk mounted to controller node"
  type        = bool
  default     = false
}

variable "disable_login_public_ips" {
  description = "If set to true, create Cloud NAT gateway and enable IAP FW rules"
  default     = false
}

variable "labels" {
  description = "Labels to add to login instances. List of key key, value pairs."
  type        = any
  default     = {}
}

variable "login_network_storage" {
  description = "An array of network attached storage mounts to be configured on the login and controller instances."
  type = list(object({
    server_ip     = string,
    remote_mount  = string,
    local_mount   = string,
    fs_type       = string,
    mount_options = string}))
  default = []
}

variable "machine_type" {
  description = "Machine type to use for login node instances."
  default     = "n1-standard-2"
}

variable "munge_key" {
  description = "Specific munge key to use"
  default     = null
}

variable "network_storage" {
  description = " An array of network attached storage mounts to be configured on all instances."
  type = list(object({
    server_ip     = string,
    remote_mount  = string,
    local_mount   = string,
    fs_type       = string,
    mount_options = string}))
  default = []
}

variable "node_count" {
  description = "Number of login nodes in the cluster"
  default     = 1
}

variable "ompi_version" {
  description = "Version/branch of OpenMPI to install with Slurm/PMI support. Allows mpi programs to be run with srun."
  default     = null
}

variable "region" {
  description = "Compute Platform region where the Slurm cluster will be located"
  type        = string
}

variable "scopes" {
  description = "Scopes to apply to login nodes."
  type        = list(string)
  default     = [
    "https://www.googleapis.com/auth/monitoring.write",
    "https://www.googleapis.com/auth/logging.write"
  ]
}

variable "service_account" {
  description = "Service Account for compute nodes."
  type        = string
  default     = "default"
}

variable "shared_vpc_host_project" {
  type    = string
  default = null
}

variable "subnet_depend" {
  description = "Used as a dependency between the network and instances"
  type        = string
  default     = ""
}

variable "subnetwork_name" {
  description = "The name of the pre-defined VPC subnet you want the nodes to attach to based on Region."
  default     = null
  type        = string
}

variable "zone" {
  description = "Compute Platform zone where the notebook server will be located"
  default     = "us-central1-b"
}

output "instance_network_ips" {
  value = ["${google_compute_instance.login_node.*.network_interface.0.network_ip}"]
}
