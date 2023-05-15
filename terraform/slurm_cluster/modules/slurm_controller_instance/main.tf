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
  region = (
    length(regexall("/regions/([^/]*)", var.subnetwork)) > 0
    ? flatten(regexall("/regions/([^/]*)", var.subnetwork))[0]
    : var.region
  )

  etc_dir = abspath("${path.module}/../../../../etc")

  service_account_email = (
    var.cloudsql != null
    ? data.google_compute_instance_template.controller_template[0].service_account[0].email
    : null
  )
}

##################
# LOCALS: CONFIG #
##################

locals {
  partitions = { for p in var.partitions : p.partition.partition_name => p.partition if lookup(p, "partition", null) != null }
}

####################
# LOCALS: METADATA #
####################

locals {
  metadata_config = {
    enable_bigquery_load = var.enable_bigquery_load
    cloudsql             = var.cloudsql != null ? true : false
    cluster_id           = random_uuid.cluster_id.result
    project              = var.project_id
    slurm_cluster_name   = var.slurm_cluster_name

    # storage
    disable_default_mounts = var.disable_default_mounts
    network_storage        = var.network_storage
    login_network_storage  = var.login_network_storage

    # timeouts
    controller_startup_scripts_timeout = var.controller_startup_scripts_timeout
    compute_startup_scripts_timeout    = var.compute_startup_scripts_timeout
    login_startup_scripts_timeout      = var.login_startup_scripts_timeout

    # slurm conf
    prolog_scripts   = [for x in google_compute_project_metadata_item.prolog_scripts : x.key]
    epilog_scripts   = [for x in google_compute_project_metadata_item.epilog_scripts : x.key]
    cloud_parameters = var.cloud_parameters
    partitions       = local.partitions
  }
}

################
# LOCALS: CONF #
################

locals {
  slurmdbd_conf_tpl = (
    var.slurmdbd_conf_tpl == null
    ? abspath("${local.etc_dir}/slurmdbd.conf.tpl")
    : abspath(var.slurmdbd_conf_tpl)
  )

  slurm_conf_tpl = (
    var.slurm_conf_tpl == null
    ? abspath("${local.etc_dir}/slurm.conf.tpl")
    : abspath(var.slurm_conf_tpl)
  )

  cgroup_conf_tpl = (
    var.cgroup_conf_tpl == null
    ? abspath("${local.etc_dir}/cgroup.conf.tpl")
    : abspath(var.cgroup_conf_tpl)
  )
}

##############
# DATA: CONF #
##############

data "local_file" "slurmdbd_conf_tpl" {
  filename = local.slurmdbd_conf_tpl
}

data "local_file" "slurm_conf_tpl" {
  filename = local.slurm_conf_tpl
}

data "local_file" "cgroup_conf_tpl" {
  filename = local.cgroup_conf_tpl
}

##################
# DATA: TEMPLATE #
##################

data "google_compute_instance_template" "controller_template" {
  count = var.cloudsql != null ? 1 : 0

  name = var.instance_template
}

##########
# RANDOM #
##########

resource "random_string" "topic_suffix" {
  length  = 8
  special = false
}

resource "random_uuid" "cluster_id" {

}

############
# INSTANCE #
############

module "slurm_controller_instance" {
  source = "../_slurm_instance"

  access_config       = var.access_config
  add_hostname_suffix = false
  hostname            = "${var.slurm_cluster_name}-controller"
  instance_template   = var.instance_template
  network             = var.network
  project_id          = var.project_id
  region              = local.region
  slurm_cluster_name  = var.slurm_cluster_name
  slurm_instance_role = "controller"
  static_ips          = var.static_ips
  subnetwork_project  = var.subnetwork_project
  subnetwork          = var.subnetwork
  zone                = var.zone

  metadata = var.metadata

  slurm_depends_on = flatten([
    var.slurm_depends_on,
    [
      google_compute_project_metadata_item.config.id,
      google_compute_project_metadata_item.slurm_conf.id,
      google_compute_project_metadata_item.cgroup_conf.id,
      google_compute_project_metadata_item.slurmdbd_conf.id,
      var.enable_devel ? module.slurm_metadata_devel[0].metadata.id : null,
    ],
  ])
  depends_on = [
    # Ensure delta when user startup scripts change
    google_compute_project_metadata_item.controller_startup_scripts,
    # Ensure nodes are destroyed before controller is
    module.cleanup_compute_nodes[0],
  ]
}

####################
# METADATA: CONFIG #
####################

resource "google_compute_project_metadata_item" "config" {
  project = var.project_id

  key   = "${var.slurm_cluster_name}-slurm-config"
  value = jsonencode(local.metadata_config)

  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}

resource "google_compute_project_metadata_item" "slurm_conf" {
  project = var.project_id

  key   = "${var.slurm_cluster_name}-slurm-tpl-slurm-conf"
  value = data.local_file.slurm_conf_tpl.content

  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}

resource "google_compute_project_metadata_item" "cgroup_conf" {
  project = var.project_id

  key   = "${var.slurm_cluster_name}-slurm-tpl-cgroup-conf"
  value = data.local_file.cgroup_conf_tpl.content

  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}

resource "google_compute_project_metadata_item" "slurmdbd_conf" {
  project = var.project_id

  key   = "${var.slurm_cluster_name}-slurm-tpl-slurmdbd-conf"
  value = data.local_file.slurmdbd_conf_tpl.content

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

resource "google_compute_project_metadata_item" "controller_startup_scripts" {
  project = var.project_id

  for_each = {
    for x in var.controller_startup_scripts
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  key   = "${var.slurm_cluster_name}-slurm-controller-script-${each.key}"
  value = each.value.content

  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}

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

#####################
# SECRETS: CLOUDSQL #
#####################

resource "google_secret_manager_secret" "cloudsql" {
  count = var.cloudsql != null ? 1 : 0

  secret_id = "${var.slurm_cluster_name}-slurm-secret-cloudsql"

  replication {
    automatic = true
  }

  labels = {
    slurm_cluster_name = var.slurm_cluster_name
  }
}

resource "google_secret_manager_secret_version" "cloudsql_version" {
  count = var.cloudsql != null ? 1 : 0

  secret      = google_secret_manager_secret.cloudsql[0].id
  secret_data = jsonencode(var.cloudsql)
}

resource "google_secret_manager_secret_iam_member" "cloudsql_secret_accessor" {
  count = var.cloudsql != null ? 1 : 0

  secret_id = google_secret_manager_secret.cloudsql[0].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.service_account_email}"
}

#################
# DESTROY NODES #
#################

# Destroy all compute nodes on `terraform destroy`
module "cleanup_compute_nodes" {
  source = "../slurm_destroy_nodes"

  count = var.enable_cleanup_compute ? 1 : 0

  slurm_cluster_name = var.slurm_cluster_name
  project_id         = var.project_id
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
