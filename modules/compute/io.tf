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
  description = "Compute Platform network the notebook server will be connected to"
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

variable "controller_secondary_disk" {
  description = "Boolean indicating whether or not to allocate a secondary disk on the controller node"
  default     = 0
}

variable "default_account" {
  type        = string
  description = "Default account to setup for accounting"
  default     = "default"
}

variable "default_users" {
  type        = string
  description = "Default users to add to the account database (added to default_account)"
}

variable "munge_key" {
  description = "Specific munge key to use (e.g. date +%s | sha512sum | cut -d' ' -f1) generate a random key if none is specified"
  default     = ""
}

variable "slurm_version" {
  description = "The Slurm version to install. The version should match the link name found at https://www.schedmd.com/downloads.php"
  default     = "18.08-latest"
}

variable "suspend_time" {
  description = "Idle time (in sec) to wait before nodes go away"
  default     = 300
}
