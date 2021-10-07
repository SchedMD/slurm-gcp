/**
 * Copyright 2021 SchedMD LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

module "slurm_cluster" {
  source = "../../../terraform"

  project_id   = var.project_id
  cluster_name = "basic"

  network = {
    auto_create_subnetworks = false
    network                 = null
    subnets_spec = [
      {
        cidr   = "10.0.0.0/24"
        region = "us-central1"
      },
    ]
    subnetwork_project = null
  }

  config = {
    cgroup_conf_tpl       = null
    cloudsql              = null
    compute_d             = null
    controller_d          = null
    jwt_key               = null
    login_network_storage = null
    munge_key             = "basic-munge-key"
    network_storage       = null
    slurm_conf_tpl        = null
    slurmdbd_conf_tpl     = null
  }

  controller_service_account = {
    email  = null
    scopes = null
  }

  controller_templates = {
    "basic-controller" = {
      additional_disks          = []
      disable_smt               = false
      disk_auto_delete          = false
      disk_labels               = {}
      disk_size_gb              = 32
      disk_type                 = null
      enable_confidential_vm    = false
      enable_shielded_vm        = false
      gpu                       = null
      instance_template         = null
      instance_template_project = null
      machine_type              = "n2d-standard-2"
      metadata                  = {}
      min_cpu_platform          = null
      preemptible               = false
      service_account           = null
      shielded_instance_config  = null
      source_image              = null
      source_image_family       = null
      source_image_project      = null
      subnet_name               = null
      subnet_region             = "us-central1"
      tags                      = []
    }
  }

  controller_instances = [
    {
      count_static  = 1
      subnet_name   = null
      subnet_region = "us-central1"
      template      = "basic-controller"
    },
  ]

  login_service_account = {
    email  = null
    scopes = null
  }

  login_templates = {
    "basic-login" = {
      additional_disks          = []
      disable_smt               = false
      disk_auto_delete          = false
      disk_labels               = {}
      disk_size_gb              = 32
      disk_type                 = null
      enable_confidential_vm    = false
      enable_shielded_vm        = false
      gpu                       = null
      instance_template         = null
      instance_template_project = null
      machine_type              = "n2d-standard-2"
      metadata                  = {}
      min_cpu_platform          = null
      preemptible               = false
      service_account           = null
      shielded_instance_config  = null
      source_image              = null
      source_image_family       = null
      source_image_project      = null
      subnet_name               = null
      subnet_region             = "us-central1"
      tags                      = []
    }
  }

  login_instances = [
    {
      count_static  = 1
      subnet_name   = null
      subnet_region = "us-central1"
      template      = "basic-login"
    },
  ]

  compute_service_account = {
    email  = null
    scopes = null
  }

  compute_templates = {
    "basic-node" = {
      additional_disks          = []
      disable_smt               = false
      disk_auto_delete          = false
      disk_labels               = {}
      disk_size_gb              = 32
      disk_type                 = null
      enable_confidential_vm    = false
      enable_shielded_vm        = false
      gpu                       = null
      instance_template         = null
      instance_template_project = null
      machine_type              = "n2d-standard-2"
      metadata                  = {}
      min_cpu_platform          = null
      preemptible               = false
      service_account           = null
      shielded_instance_config  = null
      source_image              = null
      source_image_family       = null
      source_image_project      = null
      subnet_name               = null
      subnet_region             = "us-central1"
      tags                      = []
    }
  }

  partitions = {
    "basic-debug" = {
      conf = {
        MaxTime         = "UNLIMITED"
        DisableRootJobs = "NO"
      }
      nodes = [
        {
          count_dynamic = 5
          count_static  = 0
          subnet_name   = null
          subnet_region = "us-central1"
          template      = "basic-node"
        },
      ]
    }
  }
}
