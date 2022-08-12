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
  scripts_dir = abspath("${path.module}/../../../../scripts")

  additional_disks = [
    for disk in var.additional_disks : {
      disk_name    = disk.disk_name
      device_name  = disk.device_name
      auto_delete  = disk.auto_delete
      boot         = disk.boot
      disk_size_gb = disk.disk_size_gb
      disk_type    = disk.disk_type
      disk_labels = merge(
        disk.disk_labels,
        {
          slurm_cluster_name  = var.slurm_cluster_name
          slurm_instance_role = local.slurm_instance_role
        },
      )
    }
  ]

  service_account = (
    var.service_account != null
    ? var.service_account
    : {
      email  = "default"
      scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    }
  )

  source_image_family = (
    var.source_image_family != "" && var.source_image_family != null
    ? var.source_image_family
    : "schedmd-v5-slurm-22-05-3-hpc-centos-7"
  )
  source_image_project = (
    var.source_image_project != "" && var.source_image_project != null
    ? var.source_image_project
    : "projects/schedmd-slurm-public/global/images/family"
  )

  source_image = (
    var.source_image != null
    ? var.source_image
    : ""
  )

  slurm_instance_role = var.slurm_instance_role != null ? lower(var.slurm_instance_role) : null

  name_prefix = (
    local.slurm_instance_role != null
    ? "${var.slurm_cluster_name}-${local.slurm_instance_role}-${var.name_prefix}"
    : "${var.slurm_cluster_name}-${var.name_prefix}"
  )
}

########
# DATA #
########

data "local_file" "startup" {
  filename = abspath("${local.scripts_dir}/startup.sh")
}

############
# TEMPLATE #
############

module "instance_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 7.1"

  project_id = var.project_id

  # Network
  can_ip_forward     = var.can_ip_forward
  network_ip         = var.network_ip
  network            = var.network
  region             = var.region
  subnetwork_project = var.subnetwork_project
  subnetwork         = var.subnetwork
  tags               = var.tags

  # Instance
  machine_type             = var.machine_type
  min_cpu_platform         = var.min_cpu_platform
  name_prefix              = local.name_prefix
  gpu                      = var.gpu
  service_account          = local.service_account
  shielded_instance_config = var.shielded_instance_config
  threads_per_core         = var.disable_smt && length(regexall("^(t2[ad]-\\w+-\\w+|\\w+-\\w+(-1)?)$", var.machine_type)) == 0 ? 1 : null
  enable_confidential_vm   = var.enable_confidential_vm
  enable_shielded_vm       = var.enable_shielded_vm
  preemptible              = var.preemptible
  on_host_maintenance      = var.on_host_maintenance
  labels = merge(
    var.labels,
    {
      slurm_cluster_name  = var.slurm_cluster_name
      slurm_instance_role = local.slurm_instance_role
    },
  )

  # Metadata
  startup_script = data.local_file.startup.content
  metadata = merge(
    var.metadata,
    {
      enable-oslogin      = upper(var.enable_oslogin)
      slurm_cluster_name  = var.slurm_cluster_name
      slurm_instance_role = local.slurm_instance_role
      VmDnsSetting        = "GlobalOnly"
    },
  )

  # Image
  source_image_project = local.source_image_project
  source_image_family  = local.source_image_family
  source_image         = local.source_image

  # Disk
  disk_type    = var.disk_type
  disk_size_gb = var.disk_size_gb
  auto_delete  = var.disk_auto_delete
  disk_labels = merge(
    {
      slurm_cluster_name  = var.slurm_cluster_name
      slurm_instance_role = local.slurm_instance_role
    },
    var.disk_labels,
  )
  additional_disks = local.additional_disks
}
