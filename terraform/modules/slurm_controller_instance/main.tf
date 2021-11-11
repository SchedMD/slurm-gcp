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
  project_id = (
    length(regexall("/projects/([^/]*)", var.instance_template)) > 0
    ? flatten(regexall("/projects/([^/]*)", var.instance_template))[0]
    : null
  )

  region = (
    length(regexall("/regions/([^/]*)", var.subnetwork)) > 0
    ? flatten(regexall("/regions/([^/]*)", var.subnetwork))[0]
    : var.region
  )

  scripts_dir = "${path.module}/../../../scripts"

  etc_dir = "${path.module}/../../../etc"
}

locals {
  cluster_name = (
    var.cluster_name == null
    ? random_string.cluster_name.result
    : var.cluster_name
  )

  cluster_id = (
    var.cluster_id == null
    ? random_uuid.cluster_id.result
    : var.cluster_id
  )

  munge_key = (
    var.munge_key == null
    ? random_id.munge_key.b64_std
    : var.munge_key
  )

  jwt_key = (
    var.jwt_key == null
    ? random_id.jwt_key.b64_std
    : var.jwt_key
  )

  serf_keys = (
    var.serf_keys == null || var.serf_keys == []
    ? random_id.serf_keys[*].b64_std
    : var.serf_keys
  )
}

locals {
  metadata = {
    enable-oslogin = "TRUE"
    VmDnsSetting   = "GlobalOnly"
  }

  metadata_controller = {
    instance_type = "controller"
    cluster_name  = var.cluster_name
    cluster_id    = var.cluster_id
    config = jsonencode({
      cluster_name = var.cluster_name
      project      = local.project_id

      cloudsql  = var.cloudsql
      munge_key = local.munge_key
      jwt_key   = local.jwt_key
      serf_keys = local.serf_keys

      network_storage       = var.network_storage
      login_network_storage = var.login_network_storage

      template_map = var.template_map
      partitions   = var.partitions
    })
    cgroup_conf_tpl   = data.local_file.cgroup_conf_tpl.content
    slurm_conf_tpl    = data.local_file.slurm_conf_tpl.content
    slurmdbd_conf_tpl = data.local_file.slurmdbd_conf_tpl.content
  }

  metadata_devel = (
    var.enable_devel == true
    ? {
      startup-script    = data.local_file.startup.content
      clustersync       = data.local_file.clustersync.content
      setup-script      = data.local_file.setup.content
      slurm-resume      = data.local_file.resume.content
      slurm-serf-events = data.local_file.serf_events.content
      slurm-suspend     = data.local_file.suspend.content
      slurmsync         = data.local_file.slurmsync.content
      util-script       = data.local_file.util.content
    }
    : null
  )
}

locals {
  controller_d = (
    var.controller_d == null
    ? "${local.scripts_dir}/controller.d"
    : var.controller_d
  )

  scripts_controller_d = {
    for script in fileset(local.controller_d, "[^.]*")
    : "custom-controller-${replace(script, "/[^a-zA-Z0-9-_]/", "_")}"
    => file("${local.controller_d}/${script}")
  }

  compute_d = (
    var.compute_d == null
    ? "${local.scripts_dir}/compute.d"
    : var.compute_d
  )

  scripts_compute_d = {
    for script in fileset(local.compute_d, "[^.]*")
    : "custom-compute-${replace(script, "/[^a-zA-Z0-9-_]/", "_")}"
    => file("${local.compute_d}/${script}")
  }

  slurmdbd_conf_tpl = (
    var.slurmdbd_conf_tpl == null
    ? "${local.etc_dir}/slurmdbd.conf.tpl"
    : var.slurmdbd_conf_tpl
  )

  slurm_conf_tpl = (
    var.slurm_conf_tpl == null
    ? "${local.etc_dir}/slurm.conf.tpl"
    : var.slurm_conf_tpl
  )

  cgroup_conf_tpl = (
    var.cgroup_conf_tpl == null
    ? "${local.etc_dir}/cgroup.conf.tpl"
    : var.cgroup_conf_tpl
  )
}

########
# DATA #
########

/**
 * Verify that each node in 'var.partitions' references an existing instance
 * template as mapped by 'var.template_map'.
 */
data "google_compute_instance_template" "compute_instance_templates" {
  for_each = toset(flatten(
    [for p, o in var.partitions : [for n in o.nodes : n.template]]
  ))

  project = local.project_id
  name    = var.template_map[each.value]
}

/**
 * Verify that each partition has subnetworks that exist.
 */
data "google_compute_subnetwork" "partition_subnetworks" {
  for_each = var.partitions

  self_link = each.value.subnetwork
  project   = local.project_id
  name      = each.value.subnetwork
  region    = each.value.region
}

### Script Files ###

data "local_file" "startup" {
  filename = "${local.scripts_dir}/startup.sh"
}

data "local_file" "clustersync" {
  filename = "${local.scripts_dir}/clustersync.py"
}

data "local_file" "setup" {
  filename = "${local.scripts_dir}/setup.py"
}

data "local_file" "resume" {
  filename = "${local.scripts_dir}/resume.py"
}

data "local_file" "serf_events" {
  filename = "${local.scripts_dir}/serf_events.py"
}

data "local_file" "suspend" {
  filename = "${local.scripts_dir}/suspend.py"
}

data "local_file" "slurmsync" {
  filename = "${local.scripts_dir}/slurmsync.py"
}

data "local_file" "util" {
  filename = "${local.scripts_dir}/util.py"
}

### Configuration Files ###

data "local_file" "slurmdbd_conf_tpl" {
  filename = local.slurmdbd_conf_tpl
}

data "local_file" "slurm_conf_tpl" {
  filename = local.slurm_conf_tpl
}

data "local_file" "cgroup_conf_tpl" {
  filename = local.cgroup_conf_tpl
}

##########
# RANDOM #
##########

resource "random_string" "cluster_name" {
  length  = 8
  lower   = true
  upper   = false
  special = false
  number  = false
}

resource "random_uuid" "cluster_id" {
}

resource "random_id" "munge_key" {
  byte_length = 256
}

resource "random_id" "jwt_key" {
  byte_length = 256
}

resource "random_id" "serf_keys" {
  count = 3

  # 16, 24, 32 bytes
  byte_length = 32
}

############
# INSTANCE #
############

module "slurm_controller_instance" {
  source = "../_compute_instance"

  ### network ###
  subnetwork_project = var.subnetwork_project
  network            = var.network
  subnetwork         = var.subnetwork
  region             = local.region
  zone               = var.zone
  static_ips         = var.static_ips
  access_config      = var.access_config

  ### instance ###
  instance_template   = var.instance_template
  hostname            = "${local.cluster_name}-controller"
  add_hostname_suffix = false

  ### metadata ###
  metadata_startup_script = data.local_file.startup.content
  metadata = merge(
    local.metadata,
    local.metadata_controller,
    local.scripts_controller_d,
    var.metadata_controller,
  )
}

############
# METADATA #
############

resource "google_compute_project_metadata_item" "slurm_metadata" {
  project = local.project_id

  key = "${local.cluster_name}-slurm-metadata"
  value = jsonencode(merge(
    local.metadata_devel,
    local.scripts_compute_d,
    var.metadata_compute,
  ))
}

#################
# DESTROY NODES #
#################

resource "null_resource" "destroy_nodes" {
  triggers = {
    scripts_dir = local.scripts_dir
    cluster_id  = local.cluster_id
  }

  provisioner "local-exec" {
    working_dir = self.triggers.scripts_dir
    environment = {
      PIPENV_PIPFILE = "Pipfile"
    }
    command = "pipenv install"
    when    = create
  }

  provisioner "local-exec" {
    working_dir = self.triggers.scripts_dir
    environment = {
      PIPENV_PIPFILE = "Pipfile"
    }
    command = "pipenv run ./destroy_nodes.py ${self.triggers.cluster_id}"
    when    = destroy
  }
}
