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
  scripts_dir = abspath("${path.module}/../../../scripts")

  additional_disks = [
    for disk in var.additional_disks : {
      disk_name    = disk.disk_name
      device_name  = disk.device_name
      auto_delete  = disk.auto_delete
      boot         = disk.boot
      disk_size_gb = disk.disk_size_gb
      disk_type    = disk.disk_type
      disk_labels = merge(
        { slurm_cluster_id = var.slurm_cluster_id },
        disk.disk_labels
      )
    }
  ]

  service_account = (
    var.service_account != null
    ? var.service_account
    : {
      email  = "default"
      scopes = []
    }
  )

  source_image_family = (
    var.source_image_family != ""
    ? var.source_image_family
    : "schedmd-slurm-21-08-2-hpc-centos-7"
  )
  source_image_project = (
    var.source_image_project != ""
    ? var.source_image_project
    : "schedmd-slurm-public"
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

  ### general ###
  project_id  = var.project_id
  name_prefix = "${var.cluster_name}-controller-${var.name_prefix}"

  ### network ###
  subnetwork_project = var.subnetwork_project
  network            = var.network
  subnetwork         = var.subnetwork
  region             = var.region
  tags               = var.tags
  can_ip_forward     = var.can_ip_forward
  network_ip         = var.network_ip

  ### instance ###
  machine_type             = var.machine_type
  min_cpu_platform         = var.min_cpu_platform
  gpu                      = var.gpu
  service_account          = local.service_account
  shielded_instance_config = var.shielded_instance_config
  enable_confidential_vm   = var.enable_confidential_vm
  enable_shielded_vm       = var.enable_shielded_vm
  preemptible              = var.preemptible
  on_host_maintenance      = var.on_host_maintenance
  labels = merge(
    { slurm_cluster_id = var.slurm_cluster_id },
    var.labels
  )

  ### metadata ###
  startup_script = data.local_file.startup.content
  metadata = merge(
    {
      enable-oslogin    = "TRUE"
      google_mpi_tuning = var.disable_smt == true ? "--nosmt" : null
      VmDnsSetting      = "GlobalOnly"
    },
    {
      cluster_name  = var.cluster_name
      instance_type = "controller"
    },
    var.metadata
  )

  ### source image ###
  source_image_project = local.source_image_project
  source_image_family  = local.source_image_family
  source_image         = var.source_image

  ### disk ###
  disk_type    = var.disk_type
  disk_size_gb = var.disk_size_gb
  auto_delete  = var.disk_auto_delete
  disk_labels = merge(
    { slurm_cluster_id = var.slurm_cluster_id },
    var.disk_labels
  )
  additional_disks = local.additional_disks
}
