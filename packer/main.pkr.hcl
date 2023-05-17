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
    slurm_version    = var.slurm_version
    install_cuda     = var.install_cuda
    nvidia_version   = var.nvidia_version
    nvidia_from_repo = var.nvidia_from_repo
    install_ompi     = var.install_ompi
    install_lustre   = var.install_lustre
    install_gcsfuse  = var.install_gcsfuse
  }

  parse_version = regex("^(?P<major>\\d+)(?:\\.(?P<minor>\\d+))?(?:\\.(?P<patch>\\d+))?|(?P<branch>\\w+)$", var.slurmgcp_version)
  branch        = local.parse_version["branch"] != null ? replace(local.parse_version["branch"], ".", "-") : null
  version       = join("-", compact([local.parse_version["major"], local.parse_version["minor"], local.parse_version["patch"], local.branch]))

  prefix_str  = try(length(var.prefix), 0) > 0 ? "${var.prefix}-" : ""
  root_str    = "slurm-gcp-${local.version}"
  variant_str = try(length(var.variant), 0) > 0 ? "-${var.variant}" : ""

  # If image_family_alt is set, use it instead of source_image_family
  image_os_name    = try(length(var.image_family_alt), 0) > 0 ? var.image_family_alt : var.source_image_family
  generated_family = "${local.prefix_str}${local.root_str}-${local.image_os_name}${local.variant_str}"

  # if image_family_name is set, use it for image_family instead of the generated one.
  image_family = try(length(var.image_family_name), 0) > 0 ? var.image_family_name : local.generated_family
}

##########
# SOURCE #
##########

source "googlecompute" "image" {
  ### general ###
  project_id = var.project_id
  zone       = var.zone

  ### image ###
  source_image_project_id = [var.project_id, var.source_image_project_id]
  skip_create_image       = var.skip_create_image

  ### network ###
  network_project_id = var.network_project_id
  subnetwork         = var.subnetwork
  tags               = var.tags

  ### service account ###
  service_account_email = var.service_account_email
  scopes                = var.service_account_scopes

  ### image ###
  source_image        = var.source_image
  source_image_family = var.source_image_family

  image_name        = "${local.image_family}-{{timestamp}}"
  image_family      = local.image_family
  image_description = "slurm-gcp-v5"
  image_licenses    = var.image_licenses
  image_labels      = var.labels

  ### ssh ###
  ssh_username              = var.ssh_username
  ssh_password              = var.ssh_password
  ssh_clear_authorized_keys = true
  use_iap                   = var.use_iap
  use_os_login              = var.use_os_login
  temporary_key_pair_type   = "ed25519"
  #temporary_key_pair_bits   = 0

  ### instance ###
  instance_name = "${local.image_family}-{{timestamp}}"
  machine_type  = var.machine_type
  preemptible   = var.preemptible
  labels        = var.labels

  ### disk ###
  disk_size = var.disk_size
  disk_type = var.disk_type

  ### metadata ###
  metadata = {
    block-project-ssh-keys = "TRUE"
  }

  state_timeout = "10m"
}

#########
# BUILD #
#########

build {
  ### general ###
  name = "slurm-gcp"

  sources = ["sources.googlecompute.image"]

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

  post-processor "shell-local" {
    inline = ["echo $PACKER_BUILD_NAME >> build.txt"]
  }

  ### clean up /home/packer ###
  provisioner "shell" {
    inline = [
      "sudo su root -c 'userdel -rf packer'"
    ]
  }
}
