# Copyright 2021 ${var.prefix} LLC
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
  slurm_version = regex("^(?P<major>\\d{2})\\.(?P<minor>\\d{2})(?P<end>\\.(?P<patch>\\d+)(?P<sub>-(?P<rev>\\d+\\w*))?|\\-(?P<meta>latest))$|^b:(?P<branch>.+)$", var.slurm_version)
  slurm_branch  = local.slurm_version["branch"] != null ? replace(local.slurm_version["branch"], ".", "-") : null
  slurm_semver  = join("-", compact([local.slurm_version["major"], local.slurm_version["minor"], local.slurm_version["patch"], local.slurm_branch]))

  ansible_dir = "../ansible"
  scripts_dir = "../scripts"

  ansible_vars = {
    slurm_version   = var.slurm_version
    install_cuda    = var.install_cuda
    install_ompi    = var.install_ompi
    install_lustre  = var.install_lustre
    install_gcsfuse = var.install_gcsfuse
  }
}

##########
# SOURCE #
##########

source "googlecompute" "image" {
  ### general ###
  project_id = var.project_id
  zone       = var.zone

  ### image ###
  source_image_project_id = setunion(
    [var.project_id],
    var.source_image_project_id,
  )
  skip_create_image = var.skip_create_image

  ### ssh ###
  ssh_clear_authorized_keys = true
  use_iap                   = var.use_iap
  use_os_login              = var.use_os_login

  ### network ###
  network_project_id = var.network_project_id
  subnetwork         = var.subnetwork
  tags               = var.tags

  ### service account ###
  service_account_email = var.service_account_email
  scopes                = var.service_account_scopes
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

      image_name        = "${var.prefix}-v5-slurm-${local.slurm_semver}-${source.value.source_image_family}-{{timestamp}}"
      image_family      = "${var.prefix}-v5-slurm-${local.slurm_semver}-${source.value.source_image_family}"
      image_description = "slurm-gcp-v5"
      image_licenses    = source.value.image_licenses
      image_labels      = source.value.labels

      ### ssh ###
      ssh_username = source.value.ssh_username
      ssh_password = source.value.ssh_password

      ### instance ###
      instance_name = "${var.prefix}-v5-slurm-${local.slurm_semver}-${source.value.source_image_family}-{{timestamp}}"
      machine_type  = source.value.machine_type
      preemptible   = source.value.preemptible
      labels        = source.value.labels

      ### disk ###
      disk_size = source.value.disk_size
      disk_type = source.value.disk_type

      ### metadata ###
      metadata = {
        block-project-ssh-keys = "TRUE"
      }
    }
  }

  ### provision Slurm ###
  provisioner "ansible" {
    playbook_file = "${local.ansible_dir}/playbook.yml"
    galaxy_file   = "${local.ansible_dir}/requirements.yml"
    ansible_env_vars = [
      "ANSIBLE_CONFIG=${local.ansible_dir}/ansible.cfg",
    ]
    extra_arguments = [
      "--extra-vars",
      "${jsonencode(local.ansible_vars)}",
    ]
    use_proxy = false
  }

  dynamic "provisioner" {
    # using labels this way effectively creates 'provisioner "ansible"' blocks
    labels   = ["ansible"]
    for_each = var.extra_ansible_provisioners

    content {
      playbook_file   = provisioner.value.playbook_file
      roles_path      = provisioner.value.galaxy_file
      extra_arguments = provisioner.value.extra_arguments
      user            = provisioner.value.user
    }
  }

  ### post processor ###
  post-processor "manifest" {
    output = "manifest.json"

    strip_path = false
    strip_time = false
  }

  ### clean up /home/packer ###
  provisioner "shell" {
    inline = [
      "sudo rm -rf /home/packer"
    ]
  }
}
