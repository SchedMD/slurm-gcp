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

  output_dir = (
    var.output_dir == null || var.output_dir == ""
    ? abspath(".")
    : abspath(var.output_dir)
  )

  install_dir = (
    var.install_dir == null || var.install_dir == ""
    ? local.output_dir
    : abspath(var.install_dir)
  )

  munge_mount = {
    server_ip     = lookup(var.munge_mount, "server_ip", coalesce(var.slurm_control_addr, var.slurm_control_host))
    remote_mount  = lookup(var.munge_mount, "remote_mount", "/etc/munge/")
    fs_type       = lookup(var.munge_mount, "fs_type", "nfs")
    mount_options = lookup(var.munge_mount, "mount_options", "")
  }

  template_context = {
    service_user     = var.slurm_user
    service_path     = local.install_dir
    slurmcmd_timeout = var.slurmcmd_timeout
  }
}

##################
# LOCALS: CONFIG #
##################

locals {
  partitions = { for p in var.partitions : p.partition.partition_name => p if lookup(p, "partition", null) != null }

  google_app_cred_path = (
    var.google_app_cred_path != null
    ? abspath(var.google_app_cred_path)
    : null
  )

  slurm_bin_dir = (
    var.slurm_bin_dir != null
    ? abspath(var.slurm_bin_dir)
    : null
  )

  slurm_log_dir = (
    var.slurm_log_dir != null
    ? abspath(var.slurm_log_dir)
    : null
  )

  config = {
    enable_bigquery_load = var.enable_bigquery_load
    project              = var.project_id
    slurm_cluster_name   = var.slurm_cluster_name

    # storage
    disable_default_mounts = var.disable_default_mounts
    network_storage        = var.network_storage
    login_network_storage  = var.login_network_storage
    munge_mount            = local.munge_mount

    # slurm conf
    prolog_scripts   = [for x in google_compute_project_metadata_item.prolog_scripts : x.key]
    epilog_scripts   = [for x in google_compute_project_metadata_item.epilog_scripts : x.key]
    cloud_parameters = var.cloud_parameters
    partitions       = local.partitions

    # timeouts
    compute_startup_scripts_timeout = var.compute_startup_scripts_timeout

    # hybrid
    google_app_cred_path    = local.google_app_cred_path
    output_dir              = local.output_dir
    install_dir             = local.install_dir
    slurm_control_host      = var.slurm_control_host
    slurm_control_host_port = var.slurm_control_host_port
    slurm_control_addr      = var.slurm_control_addr
    slurm_bin_dir           = local.slurm_bin_dir
    slurm_log_dir           = local.slurm_log_dir
  }
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
  filename = abspath("${var.output_dir}/resume.py")

  file_permission = "0700"
}

resource "local_file" "suspend_py" {
  content  = data.local_file.suspend_py.content
  filename = abspath("${var.output_dir}/suspend.py")

  file_permission = "0700"
}

resource "local_file" "util_py" {
  content  = data.local_file.util_py.content
  filename = abspath("${var.output_dir}/util.py")

  file_permission = "0700"
}

resource "local_file" "slurmsync_py" {
  content  = data.local_file.slurmsync_py.content
  filename = abspath("${var.output_dir}/slurmsync.py")

  file_permission = "0700"
}

resource "local_file" "startup_sh" {
  content  = data.local_file.startup_sh.content
  filename = abspath("${var.output_dir}/startup.sh")

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
  filename = abspath("${var.output_dir}/slurmcmd.service")

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
  filename = abspath("${var.output_dir}/slurmcmd.timer")

  file_permission = "0644"
}

##########
# CONFIG #
##########

resource "local_file" "config_yaml" {
  filename = abspath("${local.output_dir}/config.yaml")
  content  = yamlencode(local.config)

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

    no_comma_params = var.cloud_parameters.no_comma_params
    resume_rate     = var.cloud_parameters.resume_rate
    resume_timeout  = var.cloud_parameters.resume_timeout
    suspend_rate    = var.cloud_parameters.suspend_rate
    suspend_timeout = var.cloud_parameters.suspend_timeout
    },
    {
      for x in var.prolog_scripts
      : "prolog_d_${replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_")}"
      => sha256(x.content)
    },
    {
      for x in var.epilog_scripts
      : "epilog_d_${replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_")}"
      => sha256(x.content)
    },
  )

  provisioner "local-exec" {
    working_dir = self.triggers.scripts_dir
    environment = {
      SLURM_CONFIG_YAML = self.triggers.config_path
    }
    command = <<EOC
${self.triggers.script_path} \
--resume-rate=${self.triggers.resume_rate} \
--suspend-rate=${self.triggers.suspend_rate} \
--resume-timeout=${self.triggers.resume_timeout} \
--suspend-timeout=${self.triggers.suspend_timeout} \
${tobool(self.triggers.no_comma_params) == true ? "--no-comma-params" : ""}
EOC
  }
}

####################
# METADATA: CONFIG #
####################

resource "google_compute_project_metadata_item" "config" {
  project = var.project_id

  key   = "${var.slurm_cluster_name}-slurm-config"
  value = jsonencode(local.config)

  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}

###################
# METADATA: DEVEL #
###################

module "slurm_metadata_devel" {
  source = "../_slurm_metadata_devel"

  count = var.enable_devel ? 1 : 0

  slurm_cluster_name = var.slurm_cluster_name
  project_id         = var.project_id
}

#####################
# METADATA: SCRIPTS #
#####################

resource "google_compute_project_metadata_item" "compute_startup_scripts" {
  project = var.project_id

  for_each = {
    for x in var.compute_startup_scripts
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  key   = "${var.slurm_cluster_name}-slurm-compute-script-${each.key}"
  value = each.value.content

  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}

resource "google_compute_project_metadata_item" "prolog_scripts" {
  project = var.project_id

  for_each = {
    for x in var.prolog_scripts
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  key   = "${var.slurm_cluster_name}-slurm-prolog-script-${each.key}"
  value = each.value.content

  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}

resource "google_compute_project_metadata_item" "epilog_scripts" {
  project = var.project_id

  for_each = {
    for x in var.epilog_scripts
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  key   = "${var.slurm_cluster_name}-slurm-epilog-script-${each.key}"
  value = each.value.content

  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
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
