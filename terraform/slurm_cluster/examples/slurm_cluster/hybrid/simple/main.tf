/**
 * Copyright (C) SchedMD LLC.
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
  partitions = [
    {
      enable_job_exclusive      = false
      enable_placement_groups   = false
      network_storage           = []
      partition_conf            = {}
      partition_startup_scripts = []
      partition_name            = "debug"
      partition_nodes = [
        {
          node_count_dynamic_max = 20
          node_count_static      = 0
          group_name             = "test"
          node_conf              = {}

          additional_disks         = []
          bandwidth_tier           = "platform_default"
          can_ip_forward           = false
          disable_smt              = false
          disk_auto_delete         = true
          disk_labels              = {}
          disk_size_gb             = 32
          disk_type                = "pd-standard"
          enable_confidential_vm   = false
          enable_oslogin           = true
          enable_shielded_vm       = false
          enable_spot_vm           = false
          gpu                      = null
          instance_template        = null
          labels                   = {}
          machine_type             = "c2-standard-4"
          metadata                 = {}
          min_cpu_platform         = null
          on_host_maintenance      = null
          preemptible              = false
          service_account          = module.slurm_sa_iam["compute"].service_account
          shielded_instance_config = null
          spot_instance_config     = null
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
    {
      enable_job_exclusive    = false
      enable_placement_groups = false
      network_storage         = []
      partition_conf = {
        Default = "YES"
      }
      partition_startup_scripts = []
      partition_name            = "debug2"
      partition_nodes = [
        {
          node_count_dynamic_max = 10
          node_count_static      = 0
          group_name             = "test"
          node_conf              = {}

          additional_disks       = []
          bandwidth_tier         = "platform_default"
          can_ip_forward         = false
          disable_smt            = false
          disk_auto_delete       = true
          disk_labels            = {}
          disk_size_gb           = 32
          disk_type              = "pd-standard"
          enable_confidential_vm = false
          enable_oslogin         = true
          enable_shielded_vm     = false
          enable_spot_vm         = false
          gpu = {
            count = 1
            type  = "nvidia-tesla-v100"
          }
          instance_template        = null
          labels                   = {}
          machine_type             = "n1-standard-4"
          metadata                 = {}
          min_cpu_platform         = null
          on_host_maintenance      = null
          preemptible              = false
          service_account          = module.slurm_sa_iam["compute"].service_account
          shielded_instance_config = null
          spot_instance_config     = null
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

  controller_hybrid_config = {
    google_app_cred_path = null
    slurm_control_host   = null
    slurm_log_dir        = "/var/log/slurm"
    slurm_bin_dir        = "/usr/local/bin"
    output_dir           = "./etc"
  }
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
  source = "../../../../../slurm_cluster"

  slurm_cluster_name       = var.slurm_cluster_name
  controller_hybrid_config = local.controller_hybrid_config
  disable_default_mounts   = var.disable_default_mounts
  network_storage          = var.network_storage
  enable_hybrid            = true
  partitions               = local.partitions
  project_id               = var.project_id
}

##################
# FIREWALL RULES #
##################

module "slurm_firewall_rules" {
  source = "../../../../../slurm_firewall_rules"

  slurm_cluster_name = var.slurm_cluster_name
  network_name       = data.google_compute_subnetwork.default.network
  project_id         = var.project_id
}

##########################
# SERVICE ACCOUNTS & IAM #
##########################

module "slurm_sa_iam" {
  source = "../../../../../slurm_sa_iam"

  for_each = toset(["controller", "login", "compute"])

  account_type       = each.value
  slurm_cluster_name = var.slurm_cluster_name
  project_id         = var.project_id
}
