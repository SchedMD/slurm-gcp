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
  controller_instance_config = [
    for x in [var.controller_instance_config] : {
      access_config            = x.access_config
      additional_disks         = x.additional_disks
      can_ip_forward           = x.can_ip_forward
      disable_smt              = x.disable_smt
      disk_auto_delete         = x.disk_auto_delete
      disk_labels              = x.disk_labels
      disk_size_gb             = x.disk_size_gb
      disk_type                = x.disk_type
      enable_confidential_vm   = x.enable_confidential_vm
      enable_oslogin           = x.enable_oslogin
      enable_shielded_vm       = x.enable_shielded_vm
      gpu                      = x.gpu
      instance_template        = x.instance_template
      labels                   = x.labels
      machine_type             = x.machine_type
      metadata                 = x.metadata
      min_cpu_platform         = x.min_cpu_platform
      network_ip               = x.network_ip
      on_host_maintenance      = x.on_host_maintenance
      preemptible              = x.preemptible
      service_account          = x.service_account
      shielded_instance_config = x.shielded_instance_config
      region                   = module.slurm_network.network.subnets_regions[0]
      source_image_family      = x.source_image_family
      source_image_project     = x.source_image_project
      source_image             = x.source_image
      static_ip                = x.static_ip
      subnetwork_project       = null
      subnetwork               = module.slurm_network.network.subnets_self_links[0]
      tags                     = x.tags
      zone                     = x.zone
    }
  ]

  login_node_groups = [
    for x in var.login_node_groups : {
      access_config            = x.access_config
      additional_disks         = x.additional_disks
      can_ip_forward           = x.can_ip_forward
      disable_smt              = x.disable_smt
      disk_auto_delete         = x.disk_auto_delete
      disk_labels              = x.disk_labels
      disk_size_gb             = x.disk_size_gb
      disk_type                = x.disk_type
      enable_confidential_vm   = x.enable_confidential_vm
      enable_oslogin           = x.enable_oslogin
      enable_shielded_vm       = x.enable_shielded_vm
      gpu                      = x.gpu
      group_name               = x.group_name
      instance_template        = x.instance_template
      labels                   = x.labels
      machine_type             = x.machine_type
      metadata                 = x.metadata
      min_cpu_platform         = x.min_cpu_platform
      network_ips              = x.network_ips
      num_instances            = x.num_instances
      on_host_maintenance      = x.on_host_maintenance
      preemptible              = x.preemptible
      service_account          = x.service_account
      shielded_instance_config = x.shielded_instance_config
      region                   = module.slurm_network.network.subnets_regions[0]
      source_image_family      = x.source_image_family
      source_image_project     = x.source_image_project
      source_image             = x.source_image
      static_ips               = x.static_ips
      subnetwork_project       = null
      subnetwork               = module.slurm_network.network.subnets_self_links[0]
      tags                     = x.tags
      zone                     = x.zone
    }
  ]

  partitions = [
    for x in var.partitions : {
      enable_job_exclusive    = x.enable_job_exclusive
      enable_placement_groups = x.enable_placement_groups
      compute_node_groups     = x.compute_node_groups
      network_storage         = x.network_storage
      partition_name          = x.partition_name
      partition_conf          = x.partition_conf
      partition_d             = x.partition_d
      region                  = module.slurm_network.network.subnets_regions[0]
      subnetwork_project      = null
      subnetwork              = module.slurm_network.network.subnets_self_links[0]
      zone_policy_allow       = x.zone_policy_allow
      zone_policy_deny        = x.zone_policy_deny
    }
  ]
}

############
# PROVIDER #
############

provider "google" {
  project = var.project_id
  region  = var.region
}

###########
# NETWORK #
###########

module "slurm_network" {
  source = "../../../../modules/_network"

  auto_create_subnetworks = false
  network_name            = "${var.cluster_name}-default"
  project_id              = var.project_id

  subnets = [
    {
      subnet_name   = "${var.cluster_name}-default"
      subnet_ip     = "10.0.0.0/24"
      subnet_region = var.region

      subnet_private_access = true
      subnet_flow_logs      = true
    },
  ]
}

##################
# FIREWALL RULES #
##################

module "slurm_firewall_rules" {
  source = "../../../../modules/slurm_firewall_rules"

  cluster_name = var.cluster_name
  network_name = module.slurm_network.network.network_self_link
  project_id   = var.project_id
}

#################
# SLURM CLUSTER #
#################

module "slurm_cluster" {
  source = "../../../../modules/slurm_cluster"

  cgroup_conf_tpl            = var.cgroup_conf_tpl
  cloud_parameters           = var.cloud_parameters
  cloudsql                   = var.cloudsql
  cluster_name               = var.cluster_name
  compute_d                  = var.compute_d
  controller_instance_config = local.controller_instance_config[0]
  controller_d               = var.controller_d
  enable_devel               = var.enable_devel
  epilog_d                   = var.epilog_d
  jwt_key                    = var.jwt_key
  login_network_storage      = var.login_network_storage
  login_node_groups          = local.login_node_groups
  munge_key                  = var.munge_key
  network_storage            = var.network_storage
  partitions                 = local.partitions
  project_id                 = var.project_id
  prolog_d                   = var.prolog_d
  slurmdbd_conf_tpl          = var.slurmdbd_conf_tpl
  slurm_conf_tpl             = var.slurm_conf_tpl
}
