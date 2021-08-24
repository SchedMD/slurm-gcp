# Copyright 2021 SchedMD LLC
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

module "slurm_cluster" {
  source = "../../../terraform"

  project_id   = var.project_id
  cluster_name = "basic"

  network = {
    network            = null
    subnets            = null
    subnets_regions    = ["us-central1"]
    subnetwork_project = null
  }

  config = {
    cloudsql              = null
    jwt_key               = null
    login_network_storage = null
    munge_key             = null
    network_storage       = null
    suspend_time          = 300
  }

  controller = {
    additional_disks          = null
    count_per_region          = 1
    count_regions_covered     = 1
    disable_smt               = false
    disk_auto_delete          = false
    disk_labels               = null
    disk_size_gb              = 32
    disk_type                 = null
    enable_confidential_vm    = false
    enable_shielded_vm        = false
    gpu                       = null
    instance_template         = null
    instance_template_project = null
    machine_type              = "n2d-standard-1"
    metadata                  = null
    min_cpu_platform          = null
    preemptible               = false
    service_account           = null
    shielded_instance_config  = null
    source_image              = null
    source_image_family       = null
    source_image_project      = null
    tags                      = null
  }

  login = {
    additional_disks          = null
    count_per_region          = 1
    count_regions_covered     = 1
    disable_smt               = false
    disk_auto_delete          = false
    disk_labels               = null
    disk_size_gb              = 32
    disk_type                 = null
    enable_confidential_vm    = false
    enable_shielded_vm        = false
    gpu                       = null
    instance_template         = null
    instance_template_project = null
    machine_type              = "n2d-standard-1"
    metadata                  = null
    min_cpu_platform          = null
    preemptible               = false
    service_account           = null
    shielded_instance_config  = null
    source_image              = null
    source_image_family       = null
    source_image_project      = null
    tags                      = null
  }

  compute = {
    "compute0" = {
      additional_disks          = null
      disable_smt               = false
      disk_auto_delete          = false
      disk_labels               = null
      disk_size_gb              = 32
      disk_type                 = null
      enable_confidential_vm    = false
      enable_shielded_vm        = false
      gpu                       = null
      instance_template         = null
      instance_template_project = null
      machine_type              = "n2d-standard-1"
      metadata                  = null
      min_cpu_platform          = null
      preemptible               = false
      service_account           = null
      shielded_instance_config  = null
      source_image              = null
      source_image_family       = null
      source_image_project      = null
      tags                      = null
    },
  }
}
