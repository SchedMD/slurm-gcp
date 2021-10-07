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

### Instance ###

locals {
  tags = var.tags != null ? var.tags : []

  service_account = {
    email = (
      var.service_account.email != null
      ? var.service_account.email
      : data.google_compute_default_service_account.default.email
    )
    scopes = (
      var.service_account.scopes != null
      ? var.service_account.scopes
      : [
        "https://www.googleapis.com/auth/cloud-platform",
      ]
    )
  }

  shielded_instance_config = (
    var.shielded_instance_config != null
    ? var.shielded_instance_config
    : {
      enable_integrity_monitoring = true
      enable_secure_boot          = true
      enable_vtpm                 = true
    }
  )

  source_image_project = (
    var.source_image_project != null
    ? var.source_image_project
    : ""
  )

  source_image_family = (
    var.source_image_family != null
    ? var.source_image_family
    : "projects/schedmd-slurm-public/global/images/family/schedmd-slurm-20-11-7-centos-7"
  )

  source_image = (
    var.source_image != null
    ? var.source_image
    : ""
  )

  disk_labels = var.disk_labels != null ? var.disk_labels : {}

  additional_disks = (
    var.additional_disks != null
    ? var.additional_disks
    : []
  )
}

### Templates ###

locals {
  instance_template_project = (
    var.instance_template_project != null
    ? var.instance_template_project
    : var.project_id
  )

  instance_template = (
    var.instance_template != null
    ? data.google_compute_instance_template.template[0].self_link
    : module.template[0].self_link
  )
}

########
# DATA #
########

### Service Account ###

data "google_compute_default_service_account" "default" {
  project = var.project_id
}

### Template ###

data "google_compute_instance_template" "template" {
  count = var.instance_template != null ? 1 : 0

  project     = local.instance_template_project
  filter      = "name = ${var.instance_template}*"
  most_recent = true
}

############
# TEMPLATE #
############

module "template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 7.1"

  count = var.instance_template == null ? 1 : 0

  ### general ###
  project_id  = var.project_id
  name_prefix = var.name_prefix

  ### network ###
  subnetwork_project = var.subnetwork_project
  network            = var.network
  subnetwork         = var.subnetwork
  region             = var.region
  tags               = local.tags

  ### instance ###
  machine_type             = var.machine_type
  min_cpu_platform         = var.min_cpu_platform
  gpu                      = var.gpu
  service_account          = local.service_account
  shielded_instance_config = local.shielded_instance_config
  enable_confidential_vm   = var.enable_confidential_vm
  enable_shielded_vm       = var.enable_shielded_vm
  preemptible              = var.preemptible
  on_host_maintenance      = "MIGRATE"

  ### metadata ###
  metadata       = var.metadata

  ### source image ###
  source_image_project = local.source_image_project
  source_image_family  = local.source_image_family
  source_image         = local.source_image

  ### disk ###
  disk_type        = var.disk_type
  disk_size_gb     = var.disk_size_gb
  disk_labels      = local.disk_labels
  auto_delete      = var.disk_auto_delete
  additional_disks = local.additional_disks
}
