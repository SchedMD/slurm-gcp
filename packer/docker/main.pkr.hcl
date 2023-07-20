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

  ansible_dir = "../../ansible"

  ansible_vars = {
    slurm_version    = var.slurm_version
    install_cuda     = var.install_cuda
    nvidia_version   = var.nvidia_version
    nvidia_from_repo = var.nvidia_from_repo
    install_ompi     = var.install_ompi
    install_lustre   = var.install_lustre
    install_gcsfuse  = var.install_gcsfuse
    tf_version       = var.tf_version
  }

  gcr_repo = "${var.project_id}/tpu"
}

##########
# SOURCE #
##########

source "docker" "gcp" {
  image  = var.docker_image
  commit = true
  changes = [
    "ENV OS_ENV=slurm_container",
    "ENTRYPOINT [\"/usr/bin/systemd\"]"
  ]
}
#########
# BUILD #
#########

build {
  name = "slurm-gcp-docker"
  sources = [
    "source.docker.gcp"
  ]
  provisioner "shell" {
    script = "./install-deps-docker.sh"
  }
  provisioner "ansible" {
    playbook_file = "${local.ansible_dir}/docker-playbook.yml"
    ansible_env_vars = [
      "ANSIBLE_CONFIG=${local.ansible_dir}/ansible.cfg",
    ]
    extra_arguments = [
      "--extra-vars",
      "${jsonencode(local.ansible_vars)}",
    ]
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
  post-processors {
    post-processor "docker-tag" {
      repository = "gcr.io/${local.gcr_repo}"
      tags       = ["gcp_${var.slurmgcp_version}_tf_${var.tf_version}"]
      only       = ["docker.gcp"]
    }
  }
  #Remember to make docker push of the image to push it to gcr
}
