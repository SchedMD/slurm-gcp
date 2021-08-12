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
  image_family = "schedmd-slurm-${join("-", local.slurm_semver)}-${var.source_image_family}"
  ansible_dir  = "../ansible"
  scripts_dir  = "../scripts"
}

##########
# SOURCE #
##########

source "googlecompute" "image" {
  # account settings
  project_id = var.project
  zone       = var.zone

  # image settings
  image_name          = "${local.image_family}-{{timestamp}}"
  image_family        = local.image_family
  source_image        = var.source_image
  source_image_family = var.source_image_family
  image_licenses      = var.image_licenses
  image_description   = "slurm-gcp"
  skip_create_image   = var.skip_create_image

  # ssh settings
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password

  ssh_clear_authorized_keys = true

  # instance settings
  instance_name = "${local.image_family}-{{timestamp}}"
  machine_type  = var.machine_type
  preemptible   = var.preemptible

  # disk settings
  disk_size = var.disk_size
  disk_type = var.disk_type

  # network settings
  network_project_id = var.network_project_id
  subnetwork         = var.subnetwork
  tags               = var.tags
}

#########
# BUILD #
#########

build {
  name = "slurm-gcp"

  sources = [
    "sources.googlecompute.image",
  ]

  provisioner "ansible" {
    playbook_file = "${local.ansible_dir}/playbook.yml"
    ansible_env_vars = [
      "ANSIBLE_CONFIG=${local.ansible_dir}/ansible.cfg",
    ]
    extra_arguments = [
      "--verbose",
      "--extra-vars",
      "slurm_version=${var.slurm_version}",
    ]
  }

  post-processor "manifest" {
    output = "manifest.json"

    strip_path = false
    strip_time = false
  }
}
