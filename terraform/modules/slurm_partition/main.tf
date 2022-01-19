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
  compute_node_groups = { for x in var.compute_node_groups : x.group_name => x }

  compute_node_groups_defaults_defaults = {
    additional_disks       = []
    can_ip_forward         = null
    disable_smt            = false
    disk_auto_delete       = true
    disk_labels            = {}
    disk_size_gb           = null
    disk_type              = null
    enable_confidential_vm = false
    enable_oslogin         = true
    enable_shielded_vm     = false
    gpu                    = null
    labels                 = {}
    machine_type           = "n1-standard-1"
    min_cpu_platform       = null
    network_ip             = ""
    on_host_maintenance    = null
    preemptible            = false
    service_account = {
      email  = "default"
      scopes = []
    }
    shielded_instance_config = {
      enable_integrity_monitoring = true
      enable_secure_boot          = true
      enable_vtpm                 = true
    }
    source_image_family  = ""
    source_image_project = ""
    source_image         = ""
    tags                 = []
  }

  compute_node_groups_defaults = merge(
    local.compute_node_groups_defaults_defaults,
    var.compute_node_groups_defaults,
  )

  partition = {
    partition_name = var.partition_name
    partition_conf = var.partition_conf
    partition_nodes = {
      for x in local.compute_node_groups : x.group_name => {
        group_name        = x.group_name
        instance_template = module.slurm_compute_template[x.group_name].self_link
        count_dynamic     = lookup(x, "count_dynamic", 1)
        count_static      = lookup(x, "count_static", 0)
      }
    }
    subnetwork        = data.google_compute_subnetwork.partition_subnetwork.self_link
    zone_policy_allow = setsubtract(var.zone_policy_allow, var.zone_policy_deny)
    zone_policy_deny  = var.zone_policy_deny
    exclusive         = var.enable_placement_groups == true ? true : var.enable_job_exclusive
    placement_groups  = var.enable_placement_groups
    network_storage   = var.network_storage
  }
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

#####################
# COMPUTE: TEMPLATE #
#####################

module "slurm_compute_template" {
  source = "../slurm_compute_template"

  for_each = local.compute_node_groups

  additional_disks         = lookup(each.value, "additional_disks", local.compute_node_groups_defaults["additional_disks"])
  can_ip_forward           = lookup(each.value, "can_ip_forward", local.compute_node_groups_defaults["can_ip_forward"])
  cluster_name             = var.cluster_name
  disable_smt              = lookup(each.value, "disable_smt", local.compute_node_groups_defaults["disable_smt"])
  disk_auto_delete         = lookup(each.value, "disk_auto_delete", local.compute_node_groups_defaults["disk_auto_delete"])
  disk_labels              = lookup(each.value, "disk_labels", local.compute_node_groups_defaults["disk_labels"])
  disk_size_gb             = lookup(each.value, "disk_size_gb", local.compute_node_groups_defaults["disk_size_gb"])
  disk_type                = lookup(each.value, "disk_type", local.compute_node_groups_defaults["disk_type"])
  enable_confidential_vm   = lookup(each.value, "enable_confidential_vm", local.compute_node_groups_defaults["enable_confidential_vm"])
  enable_oslogin           = lookup(each.value, "enable_oslogin", local.compute_node_groups_defaults["enable_oslogin"])
  enable_shielded_vm       = lookup(each.value, "enable_shielded_vm", local.compute_node_groups_defaults["enable_shielded_vm"])
  gpu                      = lookup(each.value, "gpu", local.compute_node_groups_defaults["gpu"])
  machine_type             = lookup(each.value, "machine_type", local.compute_node_groups_defaults["machine_type"])
  min_cpu_platform         = lookup(each.value, "min_cpu_platform", local.compute_node_groups_defaults["min_cpu_platform"])
  name_prefix              = each.value.group_name
  network_ip               = lookup(each.value, "network_ip", local.compute_node_groups_defaults["network_ip"])
  on_host_maintenance      = lookup(each.value, "on_host_maintenance", local.compute_node_groups_defaults["on_host_maintenance"])
  preemptible              = lookup(each.value, "preemptible", local.compute_node_groups_defaults["preemptible"])
  project_id               = var.project_id
  service_account          = lookup(each.value, "service_account", local.compute_node_groups_defaults["service_account"])
  shielded_instance_config = lookup(each.value, "shielded_instance_config", local.compute_node_groups_defaults["shielded_instance_config"])
  slurm_cluster_id         = var.slurm_cluster_id
  source_image_family      = lookup(each.value, "source_image_family", local.compute_node_groups_defaults["source_image_family"])
  source_image_project     = lookup(each.value, "source_image_project", local.compute_node_groups_defaults["source_image_project"])
  source_image             = lookup(each.value, "source_image", local.compute_node_groups_defaults["source_image"])
  subnetwork               = data.google_compute_subnetwork.partition_subnetwork.self_link
  tags                     = concat([var.cluster_name], lookup(each.value, "tags", local.compute_node_groups_defaults["tags"]))
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

  key   = "${var.cluster_name}-slurm-partition-${var.partition_name}-script-${each.key}"
  value = each.value.content
}
