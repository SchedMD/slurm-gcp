# Copyright 2021 SchedMD LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

##########
# LOCALS #
##########

locals {
  slurm_semver = split(".", trimprefix(var.slurm_version, "slurm-"))

  ansible_dir = "../ansible"
  scripts_dir = "../scripts"
}

##########
# SOURCE #
##########

source "googlecompute" "image" {
  ### general ###
  project_id = var.project
  zone       = var.zone

  ### image ###
  source_image_project_id = var.source_image_project_id
  skip_create_image       = var.skip_create_image

  ### ssh ###
  ssh_clear_authorized_keys = true

  ### network ###
  network_project_id = var.network_project_id
  subnetwork         = var.subnetwork
  tags               = var.tags

  ### service account ###
  scopes = [
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/devstorage.full_control",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring.write",
  ]
}

#########
# BUILD #
#########

build {
  ### general ###
  name = "slurm-gcp"

  ### builds ###
  dynamic "source" {
    for_each = var.builds
    labels = [
      "sources.googlecompute.image",
    ]
    content {
      name = source.key

      ### image ###
      source_image        = source.value.source_image
      source_image_family = source.value.source_image_family

      image_name        = "schedmd-slurm-${join("-", local.slurm_semver)}-${source.value.source_image_family}-{{timestamp}}"
      image_family      = "schedmd-slurm-${join("-", local.slurm_semver)}-${source.value.source_image_family}"
      image_description = "slurm-gcp"
      image_licenses    = source.value.image_licenses
      image_labels      = source.value.labels

      ### ssh ###
      ssh_username = source.value.ssh_username
      ssh_password = source.value.ssh_password

      ### instance ###
      instance_name = "schedmd-slurm-${join("-", local.slurm_semver)}-${source.value.source_image_family}-{{timestamp}}"
      machine_type  = source.value.machine_type
      preemptible   = source.value.preemptible
      labels        = source.value.labels

      ### disk ###
      disk_size = source.value.disk_size
      disk_type = source.value.disk_type
    }
  }

  ### provision ###
  provisioner "ansible" {
    playbook_file = "${local.ansible_dir}/playbook.yml"
    roles_path    = "${local.ansible_dir}/roles"
    ansible_env_vars = [
      "ANSIBLE_CONFIG=${local.ansible_dir}/ansible.cfg",
    ]
    extra_arguments = [
      "--verbose",
      "--extra-vars",
      "slurm_version=${var.slurm_version}",
    ]
  }

  ### post processor ###
  post-processor "manifest" {
    output = "manifest.json"

    strip_path = false
    strip_time = false
  }
}
