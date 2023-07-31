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

###########
# NODESET #
###########

locals {
  node_conf_hw = {
    Mem334CPU96 = {
      CPUs           = 96
      Boards         = 1
      Sockets        = 2
      CoresPerSocket = 24
      ThreadsPerCore = 2
      RealMemory     = 307200
    }
  }
  node_conf_mappings = {
    "v2-8"  = local.node_conf_hw.Mem334CPU96
    "v3-8"  = local.node_conf_hw.Mem334CPU96
    "v2-32" = local.node_conf_hw.Mem334CPU96
  }
  simple_nodes = ["v2-8", "v3-8"]
}

locals {
  nodeset_tpu = {
    nodeset_name           = var.nodeset_name
    node_conf              = local.node_conf_mappings[var.node_type]
    node_type              = var.node_type
    accelerator_config     = var.accelerator_config
    tf_version             = var.tf_version
    preemptible            = contains(local.simple_nodes, var.node_type) ? var.preemptible : false
    node_count_dynamic_max = var.node_count_dynamic_max
    node_count_static      = var.node_count_static
    enable_public_ip       = var.enable_public_ip
    zone                   = var.zone
    service_account        = var.service_account != null ? var.service_account : local.service_account
    preserve_tpu           = contains(local.simple_nodes, var.node_type) ? var.preserve_tpu : false
    data_disks             = var.data_disks
    docker_image           = var.docker_image != "" ? var.docker_image : "gcr.io/schedmd-slurm-public/tpu:slurm-gcp-6-0-ubuntu-20.04-tf-${var.tf_version}"
  }

  service_account = {
    email  = coalesce(data.google_service_account.this.email, data.google_compute_default_service_account.this.email)
    scopes = try(var.service_account.scopes, ["https://www.googleapis.com/auth/cloud-platform"])
  }
}

data "google_service_account" "this" {
  account_id = coalesce(try(var.service_account.email, null), "NOT_SERVICE_ACCOUNT")
  project    = var.project_id
}

data "google_compute_default_service_account" "this" {
  project = var.project_id
}

resource "null_resource" "nodeset_tpu" {
  triggers = {
    nodeset = sha256(jsonencode(local.nodeset_tpu))
  }
  lifecycle {
    precondition {
      condition     = sum([var.node_count_dynamic_max, var.node_count_static]) > 0
      error_message = "Sum of node_count_dynamic_max and node_count_static must be > 0."
    }
  }
}
