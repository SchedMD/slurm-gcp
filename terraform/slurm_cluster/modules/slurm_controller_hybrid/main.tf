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
  scripts_dir           = abspath("${path.module}/../../../../scripts")
  slurmcmd_template_dir = abspath("${path.module}/../../../../ansible/roles/slurmcmd/templates")

  template_context = {
    service_user     = var.slurm_user
    service_path     = local.install_dir
    slurmcmd_timeout = var.slurmcmd_timeout
  }

  output_dir  = var.config.output_dir
  install_dir = var.config.install_dir
}

################
# DATA: SCRIPT #
################

data "local_file" "setup_hybrid_py" {
  filename = abspath("${local.scripts_dir}/setup_hybrid.py")
}

data "local_file" "resume_py" {
  filename = abspath("${local.scripts_dir}/resume.py")
}

data "local_file" "suspend_py" {
  filename = abspath("${local.scripts_dir}/suspend.py")
}

data "local_file" "util_py" {
  filename = abspath("${local.scripts_dir}/util.py")
}

data "local_file" "conf_py" {
  filename = abspath("${local.scripts_dir}/conf.py")
}

data "local_file" "slurmsync_py" {
  filename = abspath("${local.scripts_dir}/slurmsync.py")
}

data "local_file" "startup_sh" {
  filename = abspath("${local.scripts_dir}/startup.sh")
}

###########
# SCRIPTS #
###########

resource "local_file" "resume_py" {
  content  = data.local_file.resume_py.content
  filename = abspath("${local.output_dir}/resume.py")

  file_permission = "0700"
}

resource "local_file" "suspend_py" {
  content  = data.local_file.suspend_py.content
  filename = abspath("${local.output_dir}/suspend.py")

  file_permission = "0700"
}

resource "local_file" "util_py" {
  content  = data.local_file.util_py.content
  filename = abspath("${local.output_dir}/util.py")

  file_permission = "0700"
}

resource "local_file" "conf_py" {
  content  = data.local_file.conf_py.content
  filename = abspath("${local.output_dir}/conf.py")

  file_permission = "0700"
}

resource "local_file" "slurmsync_py" {
  content  = data.local_file.slurmsync_py.content
  filename = abspath("${local.output_dir}/slurmsync.py")

  file_permission = "0700"
}

resource "local_file" "startup_sh" {
  content  = data.local_file.startup_sh.content
  filename = abspath("${local.output_dir}/startup.sh")

  file_permission = "0700"
}

data "jinja_template" "slurmcmd_service" {
  template = abspath("${local.slurmcmd_template_dir}/slurmcmd.service.j2")
  context {
    type = "yaml"
    data = yamlencode(local.template_context)
  }
}
resource "local_file" "slurmcmd_service" {
  content  = data.jinja_template.slurmcmd_service.result
  filename = abspath("${local.output_dir}/slurmcmd.service")

  file_permission = "0644"
}

data "jinja_template" "slurmcmd_timer" {
  template = abspath("${local.slurmcmd_template_dir}/slurmcmd.timer.j2")
  context {
    type = "yaml"
    data = yamlencode(local.template_context)
  }
}
resource "local_file" "slurmcmd_timer" {
  content  = data.jinja_template.slurmcmd_timer.result
  filename = abspath("${local.output_dir}/slurmcmd.timer")

  file_permission = "0644"
}

##########
# CONFIG #
##########

resource "local_file" "config_yaml" {
  filename = abspath("${local.output_dir}/config.yaml")
  content  = yamlencode(var.config)

  file_permission = "0600"
}

#########
# SETUP #
#########

resource "null_resource" "setup_hybrid" {
  triggers = merge({
    scripts_dir = local.scripts_dir
    config_dir  = local.output_dir
    config      = local_file.config_yaml.content
    config_path = local_file.config_yaml.filename
    script_path = data.local_file.setup_hybrid_py.filename
    },
  )

  provisioner "local-exec" {
    working_dir = self.triggers.scripts_dir
    environment = {
      SLURM_CONFIG_YAML = self.triggers.config_path
    }
    command = self.triggers.script_path
  }
}

#################
# DESTROY NODES #
#################

# Destroy all compute nodes on `terraform destroy`
module "cleanup_compute_nodes" {
  source = "../slurm_destroy_nodes"

  count = var.enable_cleanup_compute ? 1 : 0

  project_id         = var.project_id
  slurm_cluster_name = var.slurm_cluster_name
  when_destroy       = true
}

#############################
# DESTROY RESOURCE POLICIES #
#############################

# Destroy all resource policies on `terraform destroy`
module "cleanup_resource_policies" {
  source = "../slurm_destroy_resource_policies"

  count = var.enable_cleanup_compute ? 1 : 0

  slurm_cluster_name = var.slurm_cluster_name
  project_id         = var.project_id
  when_destroy       = true
}
