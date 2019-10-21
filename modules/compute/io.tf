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

variable "project" {
  type        = string
  description = "Cloud Platform project that hosts the notebook server(s)"
}

variable "zone" {
  type        = string
  description = "Compute Platform zone where the notebook server will be located"
  default     = "us-central1-b"
}

variable "network" {
  type        = string
  description = "Compute Platform network the Slurm cluster nodes will be connected to"
  default     = "default"
}

variable "subnet" {
  type        = string
  description = "Compute Platform network the Slurm cluster nodes will be connected to"
  default     = "default"
}

variable "nfs_apps_server" {
  description = "IP address of the NFS server hosting the apps directory"
  default     = ""
}

variable "nfs_home_server" {
  description = "IP address of the NFS server hosting the home directory"
  default     = ""
}

variable "external_compute_ips" {
  type        = number
  description = "Boolean indicating whether or not compute nodes are assigned external IPs"
  default     = 0 
}

variable "cluster_name" {
  type        = string
  description = "Name of the Slurm cluster"
}

variable "controller_name" {
  description = "FQDN or IP address of the controller node"
}

variable "machine_type" {
  description = "Compute Platform machine type to use in controller node creation"
  default     = "n1-standard-4"
}

variable "boot_disk_type" {
  description = "Type of boot disk to create for the cluster controller node"
  default     = "pd-ssd"
}

variable "boot_disk_size" {
  description = "Size of boot disk to create for the cluster controller node"
  default     = 64
}

variable "controller_secondary_disk" {
  description = "Boolean indicating whether or not to allocate a secondary disk on the controller node"
  default     = 0
}

variable "munge_key" {
  description = "Specific munge key to use (e.g. date +%s | sha512sum | cut -d' ' -f1) generate a random key if none is specified"
  default     = ""
}

variable "image_count" {
  description = "The number of auto-scaling compute images to create"
  default     = 1
}

variable "partitions" {
  type = list(object({
              name                 = string,
              machine_type         = string,
              max_node_count       = number,
              zone                 = string,
              compute_disk_type    = string,
              compute_disk_size_gb = number,
              compute_labels       = list(string),
              cpu_platform         = string,
              gpu_type             = string,
              gpu_count            = number,
              preemptible_bursting = number,
              static_node_count    = number}))
}
