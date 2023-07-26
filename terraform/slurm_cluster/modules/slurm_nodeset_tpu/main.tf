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
    single = {
      CPUs           = 96
      Boards         = 1
      Sockets        = 2
      CoresPerSocket = 24
      ThreadsPerCore = 2
      RealMemory     = 307200
    }
  }
  node_conf_mappings = {
    "v2-8" = local.node_conf_hw.single
    "v3-8" = local.node_conf_hw.single
  }

}

locals {

  nodeset_tpu = {
    nodeset_name           = var.nodeset_name
    node_conf              = local.node_conf_mappings[var.node_type]
    node_type              = var.node_type
    accelerator_config     = var.accelerator_config
    tf_version             = var.tf_version
    preemptible            = var.preemptible
    project_id             = var.project_id
    node_count_dynamic_max = var.node_count_dynamic_max
    node_count_static      = var.node_count_static
    enable_public_ip       = var.enable_public_ip
    zone                   = var.zone
    service_account        = var.service_account
    preserve_tpu           = var.preserve_tpu
    data_disks             = var.data_disks
    # subnetwork             = var.subnetwork_self_link

  }
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
