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
      service_account          = module.slurm_sa_iam["controller"].service_account
      shielded_instance_config = x.shielded_instance_config
      region                   = x.region
      source_image_family      = x.source_image_family
      source_image_project     = x.source_image_project
      source_image             = x.source_image
      static_ip                = x.static_ip
      subnetwork_project       = null
      subnetwork               = module.slurm_network.network.network_name
      tags                     = x.tags
      zone                     = x.zone
    }
  ]

  login_nodes = [
    for x in var.login_nodes : {
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
      service_account          = module.slurm_sa_iam["login"].service_account
      shielded_instance_config = x.shielded_instance_config
      region                   = x.region
      source_image_family      = x.source_image_family
      source_image_project     = x.source_image_project
      source_image             = x.source_image
      static_ips               = x.static_ips
      subnetwork_project       = null
      subnetwork               = module.slurm_network.network.network_name
      tags                     = x.tags
      zone                     = x.zone
    }
  ]

  partitions = [
    for x in var.partitions : {
      enable_job_exclusive      = x.enable_job_exclusive
      enable_placement_groups   = x.enable_placement_groups
      network_storage           = x.network_storage
      partition_conf            = x.partition_conf
      partition_startup_scripts = x.partition_startup_scripts
      partition_name            = x.partition_name
      partition_nodes = [for n in x.partition_nodes : {
        additional_disks         = n.additional_disks
        bandwidth_tier           = n.bandwidth_tier
        can_ip_forward           = n.can_ip_forward
        node_count_dynamic_max   = n.node_count_dynamic_max
        node_count_static        = n.node_count_static
        disable_smt              = n.disable_smt
        disk_auto_delete         = n.disk_auto_delete
        disk_labels              = n.disk_labels
        disk_size_gb             = n.disk_size_gb
        disk_type                = n.disk_type
        enable_confidential_vm   = n.enable_confidential_vm
        enable_oslogin           = n.enable_oslogin
        enable_shielded_vm       = n.enable_shielded_vm
        enable_spot_vm           = n.enable_spot_vm
        gpu                      = n.gpu
        group_name               = n.group_name
        instance_template        = n.instance_template
        labels                   = n.labels
        machine_type             = n.machine_type
        metadata                 = n.metadata
        min_cpu_platform         = n.min_cpu_platform
        node_conf                = n.node_conf
        on_host_maintenance      = n.on_host_maintenance
        preemptible              = n.preemptible
        service_account          = module.slurm_sa_iam["compute"].service_account
        shielded_instance_config = n.shielded_instance_config
        spot_instance_config     = n.spot_instance_config
        source_image_family      = n.source_image_family
        source_image_project     = n.source_image_project
        source_image             = n.source_image
        tags                     = n.tags
      }]
      region             = x.region
      subnetwork_project = null
      subnetwork         = module.slurm_network.network.network_name
      zone_policy_allow  = x.zone_policy_allow
      zone_policy_deny   = x.zone_policy_deny
    }
  ]

  cloud_parameters = merge(var.cloud_parameters, {
    no_comma_params = false
  })

  network_name = "${var.slurm_cluster_name}-default"

  subnets = [for s in var.subnets : merge(s, {
    subnet_name           = local.network_name
    subnet_region         = lookup(s, "subnet_region", var.region)
    subnet_private_access = true
  })]
}

############
# PROVIDER #
############

provider "google" {
  project = var.project_id
  region  = var.region
}

##############
# Google API #
##############

module "project_services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 12.0"

  project_id = var.project_id

  activate_apis = [
    "compute.googleapis.com",
    "iam.googleapis.com",
  ]

  enable_apis                 = true
  disable_services_on_destroy = false
}

###########
# NETWORK #
###########

module "slurm_network" {
  source = "../../../../../_network"

  auto_create_subnetworks = false
  mtu                     = var.mtu
  network_name            = local.network_name
  project_id              = var.project_id

  subnets = local.subnets

  depends_on = [
    # Ensure services are enabled
    module.project_services,
  ]
}

##################
# FIREWALL RULES #
##################

module "slurm_firewall_rules" {
  source = "../../../../../slurm_firewall_rules"

  slurm_cluster_name = var.slurm_cluster_name
  network_name       = module.slurm_network.network.network_self_link
  project_id         = var.project_id

  depends_on = [
    # Ensure services are enabled
    module.project_services,
  ]
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

  depends_on = [
    # Ensure services are enabled
    module.project_services,
  ]
}

#################
# SLURM CLUSTER #
#################

module "slurm_cluster" {
  source = "../../../../../slurm_cluster"

  cgroup_conf_tpl            = var.cgroup_conf_tpl
  cloud_parameters           = local.cloud_parameters
  cloudsql                   = var.cloudsql
  slurm_cluster_name         = var.slurm_cluster_name
  compute_startup_scripts    = var.compute_startup_scripts
  controller_instance_config = local.controller_instance_config[0]
  controller_startup_scripts = var.controller_startup_scripts
  enable_devel               = var.enable_devel
  enable_cleanup_compute     = var.enable_cleanup_compute
  enable_bigquery_load       = var.enable_bigquery_load
  enable_reconfigure         = var.enable_reconfigure
  epilog_scripts             = var.epilog_scripts
  login_startup_scripts      = var.login_startup_scripts
  login_network_storage      = var.login_network_storage
  login_nodes                = local.login_nodes
  disable_default_mounts     = var.disable_default_mounts
  network_storage            = var.network_storage
  partitions                 = local.partitions
  project_id                 = var.project_id
  prolog_scripts             = var.prolog_scripts
  slurmdbd_conf_tpl          = var.slurmdbd_conf_tpl
  slurm_conf_tpl             = var.slurm_conf_tpl

  depends_on = [
    # Ensure services are enabled
    module.project_services,
    # Guarantee the network is created before slurm cluster
    module.slurm_network,
  ]
}
