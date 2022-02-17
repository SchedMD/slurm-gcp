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
  partition = {
    partition_name = var.partition_name
    partition_conf = var.partition_conf
    partition_nodes = {
      for x in var.partition_nodes : x.group_name => {
        group_name        = x.group_name
        node_conf         = x.node_conf
        partition_name    = var.partition_name
        instance_template = data.google_compute_instance_template.group_template[x.group_name].self_link
        count_dynamic     = x.count_dynamic
        count_static      = x.count_static
      }
    }
    subnetwork              = data.google_compute_subnetwork.partition_subnetwork.self_link
    zone_policy_allow       = setsubtract(var.zone_policy_allow, var.zone_policy_deny)
    zone_policy_deny        = var.zone_policy_deny
    enable_job_exclusive    = local.enable_placement_groups || var.enable_job_exclusive
    enable_placement_groups = local.enable_placement_groups
    network_storage         = var.network_storage
  }

  enable_placement_groups = var.enable_placement_groups && alltrue([
    for x in data.google_compute_instance_template.group_template
    : length(regexall("^c2[0-9a-z]*-[0-9a-z]+-[0-9]+$", x.machine_type)) > 0
  ])

  compute_list = flatten([
    for x in local.partition.partition_nodes
    : formatlist("%s-%s-%s-%g",
      var.slurm_cluster_name,
      x.partition_name,
      x.group_name,
      range(0, sum([x.count_static, x.count_dynamic]))
    )
  ])
}

####################
# DATA: SUBNETWORK #
####################

data "google_compute_subnetwork" "partition_subnetwork" {
  project = var.subnetwork_project
  region  = var.region
  name    = var.subnetwork
  self_link = (
    length(regexall("/projects/([^/]*)", var.subnetwork)) > 0
    && length(regexall("/regions/([^/]*)", var.subnetwork)) > 0
    ? var.subnetwork
    : null
  )
}

##################
# DATA: TEMPLATE #
##################

data "google_compute_instance_template" "group_template" {
  for_each = { for x in var.partition_nodes : x.group_name => x }

  name = (
    each.value.instance_template != null && each.value.instance_template != ""
    ? each.value.instance_template
    : module.slurm_compute_template[each.value.group_name].self_link
  )
  project = var.project_id
}

#####################
# COMPUTE: TEMPLATE #
#####################

module "slurm_compute_template" {
  source = "../slurm_instance_template"

  for_each = {
    for x in var.partition_nodes : x.group_name => x
    if(x.instance_template == null || x.instance_template == "")
  }

  additional_disks         = each.value.additional_disks
  can_ip_forward           = each.value.can_ip_forward
  slurm_cluster_name       = var.slurm_cluster_name
  disable_smt              = each.value.disable_smt
  disk_auto_delete         = each.value.disk_auto_delete
  disk_labels              = each.value.disk_labels
  disk_size_gb             = each.value.disk_size_gb
  disk_type                = each.value.disk_type
  enable_confidential_vm   = each.value.enable_confidential_vm
  enable_oslogin           = each.value.enable_oslogin
  enable_shielded_vm       = each.value.enable_shielded_vm
  gpu                      = each.value.gpu
  labels                   = each.value.labels
  machine_type             = each.value.machine_type
  metadata                 = each.value.metadata
  min_cpu_platform         = each.value.min_cpu_platform
  name_prefix              = "${var.partition_name}-${each.value.group_name}"
  on_host_maintenance      = each.value.on_host_maintenance
  preemptible              = each.value.preemptible
  project_id               = var.project_id
  service_account          = each.value.service_account
  shielded_instance_config = each.value.shielded_instance_config
  slurm_cluster_id         = var.slurm_cluster_id
  slurm_instance_role      = "compute"
  source_image_family      = each.value.source_image_family
  source_image_project     = each.value.source_image_project
  source_image             = each.value.source_image
  subnetwork               = data.google_compute_subnetwork.partition_subnetwork.self_link
  tags                     = concat([var.slurm_cluster_name], each.value.tags)
}

############
# METADATA #
############

resource "google_compute_project_metadata_item" "partition_d" {
  project = var.project_id

  for_each = {
    for x in var.partition_d
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  key   = "${var.slurm_cluster_name}-slurm-partition-${var.partition_name}-script-${each.key}"
  value = each.value.content
}

###########################
# DESTROY NODES: CRITICAL #
###########################

# Destroy all compute nodes when partition environment changes
module "delta_critical" {
  source = "../slurm_destroy_nodes"

  slurm_cluster_id = var.slurm_cluster_id
  target_list      = local.compute_list

  triggers = merge(
    {
      for x in var.partition_d
      : "partition_d_${replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_")}"
      => sha256(x.content)
    },
    {
      subnetwork              = local.partition.subnetwork
      enable_placement_groups = local.partition.enable_placement_groups
    }
  )

  depends_on = [
    # Ensure partition_d metadata is updated before destroying nodes
    google_compute_project_metadata_item.partition_d,
  ]
}

##############################
# DESTROY NODES: NODE GROUPS #
##############################

# Destroy compute group when node groups change
module "delta_node_groups" {
  source = "../slurm_destroy_nodes"

  for_each = local.partition.partition_nodes

  slurm_cluster_id = var.slurm_cluster_id
  target_list = flatten([formatlist("%s-%s-%s-%g",
    var.slurm_cluster_name,
    each.value.partition_name,
    each.value.group_name,
    range(0, sum([each.value.count_static, each.value.count_dynamic]))
  )])

  triggers = {
    instance_template = each.value.instance_template
  }

  depends_on = [
    # Prevent race condition
    module.delta_critical,
  ]
}

#############################
# DESTROY RESOURCE POLICIES #
#############################

# Destroy partition resource policies when they change
module "delta_placement_groups" {
  source = "../slurm_destroy_resource_policies"

  slurm_cluster_name = var.slurm_cluster_name
  partition_name     = local.partition.partition_name

  triggers = {
    enable_placement_groups = local.partition.enable_placement_groups
  }
}
