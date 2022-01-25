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

##########
# LOCALS #
##########

locals {
  controller_instance_config = {
    access_config          = []
    additional_disks       = []
    can_ip_forward         = false
    disable_smt            = false
    disk_auto_delete       = true
    disk_labels            = {}
    disk_size_gb           = 32
    disk_type              = "pd-standard"
    enable_confidential_vm = false
    enable_oslogin         = true
    enable_shielded_vm     = false
    gpu                    = null
    instance_template      = null
    labels                 = {}
    machine_type           = "n1-standard-1"
    metadata               = {}
    min_cpu_platform       = null
    network_ip             = null
    num_instances          = 1
    on_host_maintenance    = null
    preemptible            = false
    region                 = null
    service_account = {
      email = "default"
      scopes = [
        "https://www.googleapis.com/auth/cloud-platform",
      ]
    }
    shielded_instance_config = null
    source_image_family      = null
    source_image_project     = null
    source_image             = null
    static_ip                = null
    subnetwork_project       = null
    subnetwork               = data.google_compute_subnetwork.default.self_link
    tags                     = []
    zone                     = null
  }

  login_node_groups = [
    {
      group_name = "l0"

      access_config          = []
      additional_disks       = []
      can_ip_forward         = false
      disable_smt            = false
      disk_auto_delete       = true
      disk_labels            = {}
      disk_size_gb           = 32
      disk_type              = "pd-standard"
      enable_confidential_vm = false
      enable_oslogin         = true
      enable_shielded_vm     = false
      gpu                    = null
      instance_template      = null
      labels                 = {}
      machine_type           = "n1-standard-1"
      metadata               = {}
      min_cpu_platform       = null
      network_ips            = []
      num_instances          = 1
      on_host_maintenance    = null
      preemptible            = false
      region                 = null
      service_account = {
        email = "default"
        scopes = [
          "https://www.googleapis.com/auth/cloud-platform",
        ]
      }
      shielded_instance_config = null
      source_image_family      = null
      source_image_project     = null
      source_image             = null
      static_ips               = []
      subnetwork_project       = null
      subnetwork               = data.google_compute_subnetwork.default.self_link
      tags                     = []
      zone                     = null
    }
  ]

  partitions = [
    {
      enable_job_exclusive    = false
      enable_placement_groups = false
      network_storage         = []
      partition_conf = {
        Default = "YES"
      }
      partition_d    = []
      partition_name = "debug"
      compute_node_groups = [
        {
          count_dynamic = 10
          count_static  = 0
          group_name    = "test"

          additional_disks       = []
          can_ip_forward         = false
          disable_smt            = false
          disk_auto_delete       = true
          disk_labels            = {}
          disk_size_gb           = 32
          disk_type              = "pd-standard"
          enable_confidential_vm = false
          enable_oslogin         = true
          enable_shielded_vm     = false
          gpu                    = null
          instance_template      = null
          labels                 = {}
          machine_type           = "n1-standard-1"
          metadata               = {}
          min_cpu_platform       = null
          on_host_maintenance    = null
          preemptible            = false
          service_account = {
            email = "default"
            scopes = [
              "https://www.googleapis.com/auth/cloud-platform",
            ]
          }
          shielded_instance_config = null
          source_image_family      = null
          source_image_project     = null
          source_image             = null
          tags                     = []
        },
      ]
      region             = null
      subnetwork_project = null
      subnetwork         = data.google_compute_subnetwork.default.self_link
      zone_policy_allow  = []
      zone_policy_deny   = []
    },
  ]
}

############
# PROVIDER #
############

provider "google" {
  project = var.project_id
  region  = var.region
}

########
# DATA #
########

data "google_compute_subnetwork" "default" {
  name = "default"
}

#################
# SLURM CLUSTER #
#################

module "slurm_cluster" {
  source = "../../../../modules/slurm_cluster"

  cluster_name               = var.cluster_name
  controller_instance_config = local.controller_instance_config
  login_node_groups          = local.login_node_groups
  partitions                 = local.partitions
  project_id                 = var.project_id
}

##################
# FIREWALL RULES #
##################

module "slurm_firewall_rules" {
  source = "../../../../modules/slurm_firewall_rules"

  cluster_name = var.cluster_name
  network_name = data.google_compute_subnetwork.default.network
  project_id   = var.project_id
}
