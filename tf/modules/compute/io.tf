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

variable "controller_name" {
  type        = string
  description = "FQDN or IP address of the controller node"
}

variable "controller_secondary_disk" {
  description = "Boolean indicating whether or not to allocate a secondary disk on the controller node"
  default     = 0
}

variable "cluster_name" {
  type        = string
  description = "Name of the Slurm cluster"
}

variable "disable_compute_public_ips" {
  description = "If set to true, create Cloud NAT gateway and enable IAP FW rules"
  default     = false
}

variable "machine_type" {
  description = "Compute Platform machine type to use in controller node creation"
  default     = "n1-standard-4"
}

variable "munge_key" {
  description = "Specific munge key to use (e.g. date +%s | sha512sum | cut -d' ' -f1) generate a random key if none is specified"
  default     = ""
}

variable "network_storage" {
  description = " An array of network attached storage mounts to be configured on all instances."
  type = list(object({
    server_ip    = string,
    remote_mount = string,
    local_mount  = string,
    fs_type      = string,
  mount_options = string }))
  default = []
}

variable "partitions" {
  description = "An array of configurations for specifying multiple machine types residing in their own Slurm partitions."
  type = list(object({
    name                 = string,
    machine_type         = string,
    max_node_count       = number,
    zone                 = string,
    image                = string,
    image_hyperthreads   = bool,
    compute_disk_type    = string,
    compute_disk_size_gb = number,
    compute_labels       = any,
    cpu_platform         = string,
    gpu_type             = string,
    gpu_count            = number,
    network_storage = list(object({
      server_ip    = string,
      remote_mount = string,
      local_mount  = string,
      fs_type      = string,
    mount_options = string })),
    preemptible_bursting = bool,
    vpc_subnet           = string,
    exclusive            = bool,
    enable_placement     = bool,
    regional_capacity    = bool,
    regional_policy      = any,
    instance_template    = string,
  static_node_count = number }))
}

variable "project" {
  description = "Cloud Platform project that hosts the notebook server(s)"
  type        = string
}

variable "region" {
  description = "Compute Platform region where the Slurm cluster will be located"
  type        = string
}

variable "scopes" {
  description = "Scopes to apply to compute nodes."
  type        = list(string)
  default = [
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
  type        = string
  description = "Compute Platform zone where the notebook server will be located"
  default     = "us-central1-b"
}
