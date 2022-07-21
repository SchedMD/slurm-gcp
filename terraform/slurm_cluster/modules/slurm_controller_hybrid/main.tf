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
  scripts_dir = abspath("${path.module}/../../../../scripts")

  output_dir = (
    var.output_dir == null || var.output_dir == ""
    ? abspath(".")
    : abspath(var.output_dir)
  )
}

##################
# LOCALS: CONFIG #
##################

locals {
  partitions   = { for p in var.partitions[*].partition : p.partition_name => p }
  compute_list = flatten(var.partitions[*].compute_list)

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
    enable_reconfigure   = var.enable_reconfigure
    project              = var.project_id
    pubsub_topic_id      = var.enable_reconfigure ? google_pubsub_topic.this[0].name : null
    slurm_cluster_name   = var.slurm_cluster_name

    # storage
    network_storage       = var.network_storage
    login_network_storage = var.login_network_storage

    # slurm conf
    prolog_scripts   = [for x in google_compute_project_metadata_item.prolog_scripts : x.key]
    epilog_scripts   = [for x in google_compute_project_metadata_item.epilog_scripts : x.key]
    cloud_parameters = var.cloud_parameters
    partitions       = local.partitions

    # hybrid
    google_app_cred_path = local.google_app_cred_path
    output_dir           = local.output_dir
    slurm_control_host   = var.slurm_control_host
    slurm_bin_dir        = local.slurm_bin_dir
    slurm_log_dir        = local.slurm_log_dir
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

##########
# RANDOM #
##########

resource "random_string" "topic_suffix" {
  length  = 8
  special = false
}

###########
# SCRIPTS #
###########

resource "local_file" "resume_py" {
  content  = data.local_file.resume_py.content
  filename = abspath("${var.output_dir}/resume.py")
}

resource "local_file" "suspend_py" {
  content  = data.local_file.suspend_py.content
  filename = abspath("${var.output_dir}/suspend.py")
}

resource "local_file" "util_py" {
  content  = data.local_file.util_py.content
  filename = abspath("${var.output_dir}/util.py")
}

resource "local_file" "slurmsync_py" {
  content  = data.local_file.slurmsync_py.content
  filename = abspath("${var.output_dir}/slurmsync.py")
}

resource "local_file" "startup_sh" {
  content  = data.local_file.startup_sh.content
  filename = abspath("${var.output_dir}/startup.sh")
}

##########
# CONFIG #
##########

resource "local_file" "config_yaml" {
  filename = abspath("${local.output_dir}/config.yaml")
  content  = yamlencode(local.config)

  file_permission = "0644"
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
}

resource "google_compute_project_metadata_item" "prolog_scripts" {
  project = var.project_id

  for_each = {
    for x in var.prolog_scripts
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  key   = "${var.slurm_cluster_name}-slurm-prolog-script-${each.key}"
  value = each.value.content
}

resource "google_compute_project_metadata_item" "epilog_scripts" {
  project = var.project_id

  for_each = {
    for x in var.epilog_scripts
    : replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_") => x
  }

  key   = "${var.slurm_cluster_name}-slurm-epilog-script-${each.key}"
  value = each.value.content
}

##################
# PUBSUB: SCHEMA #
##################

resource "google_pubsub_schema" "this" {
  count = var.enable_reconfigure ? 1 : 0

  name       = "${var.slurm_cluster_name}-slurm-events"
  type       = "PROTOCOL_BUFFER"
  definition = <<EOD
syntax = "proto3";
message Results {
  string request = 1;
  string timestamp = 2;
}
EOD

  lifecycle {
    create_before_destroy = true
  }
}

#################
# PUBSUB: TOPIC #
#################

resource "google_pubsub_topic" "this" {
  count = var.enable_reconfigure ? 1 : 0

  name = "${var.slurm_cluster_name}-slurm-events-${random_string.topic_suffix.result}"

  schema_settings {
    schema   = google_pubsub_schema.this[0].id
    encoding = "JSON"
  }

  labels = {
    slurm_cluster_name = var.slurm_cluster_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

####################
# NOTIFY: RECONFIG #
####################

module "reconfigure_notify" {
  source = "../slurm_notify_cluster"

  count = var.enable_reconfigure ? 1 : 0

  topic = google_pubsub_topic.this[0].name
  type  = "reconfig"

  triggers = {
    compute_list = join(",", local.compute_list)
    config       = sha256(google_compute_project_metadata_item.config.value)
  }

  depends_on = [
    # Ensure topic is created
    google_pubsub_topic.this,
    # Ensure config.yaml is created
    null_resource.setup_hybrid,
  ]
}

#################
# NOTIFY: DEVEL #
#################

module "devel_notify" {
  source = "../slurm_notify_cluster"

  count = var.enable_devel && var.enable_reconfigure ? 1 : 0

  topic = google_pubsub_topic.this[0].name
  type  = "devel"

  triggers = {
    devel = sha256(module.slurm_metadata_devel[0].metadata.value)
  }

  depends_on = [
    # Ensure topic is created
    google_pubsub_topic.this,
  ]
}

#################
# DESTROY NODES #
#################

# Destroy all compute nodes on `terraform destroy`
module "cleanup_compute_nodes" {
  source = "../slurm_destroy_nodes"

  count = var.enable_cleanup_compute ? 1 : 0

  slurm_cluster_name = var.slurm_cluster_name
  when_destroy       = true
}

module "cleanup_subscriptions" {
  source = "../slurm_destroy_subscriptions"

  count = var.enable_cleanup_subscriptions ? 1 : 0

  slurm_cluster_name = var.slurm_cluster_name
  when_destroy       = true
}

# Destroy all compute nodes when the compute node environment changes
module "reconfigure_critical" {
  source = "../slurm_destroy_nodes"

  count = var.enable_reconfigure ? 1 : 0

  slurm_cluster_name = var.slurm_cluster_name

  triggers = merge(
    {
      for x in var.compute_startup_scripts
      : "compute_d_${replace(basename(x.filename), "/[^a-zA-Z0-9-_]/", "_")}" => sha256(x.content)
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
    {
      controller_id = null_resource.setup_hybrid.id
    },
  )
}

# Destroy all removed compute nodes when partitions change
module "reconfigure_partitions" {
  source = "../slurm_destroy_nodes"

  count = var.enable_reconfigure ? 1 : 0

  slurm_cluster_name = var.slurm_cluster_name
  exclude_list       = local.compute_list

  triggers = {
    compute_list = join(",", local.compute_list)
  }

  depends_on = [
    # Prevent race condition
    module.reconfigure_critical,
  ]
}

#############################
# DESTROY RESOURCE POLICIES #
#############################

# Destroy all resource policies on `terraform destroy`
module "cleanup_resource_policies" {
  source = "../slurm_destroy_resource_policies"

  count = var.enable_cleanup_compute ? 1 : 0

  slurm_cluster_name = var.slurm_cluster_name
  when_destroy       = true
}
