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
  partition_conf = merge({
    "Default"        = var.default ? "YES" : null
    "ResumeTimeout"  = var.resume_timeout != 0 ? var.resume_timeout : length(var.partition_nodeset_tpu) > 0 ? 600 : 300
    "SuspendTime"    = var.suspend_time < 0 ? "INFINITE" : var.suspend_time
    "SuspendTimeout" = var.suspend_timeout != 0 ? var.suspend_timeout : length(var.partition_nodeset_tpu) > 0 ? 240 : 120
  }, var.partition_conf)

  partition = {
    partition_name        = var.partition_name
    partition_conf        = local.partition_conf
    partition_nodeset     = var.partition_nodeset
    partition_nodeset_dyn = var.partition_nodeset_dyn
    partition_nodeset_tpu = var.partition_nodeset_tpu
    network_storage       = var.network_storage
    # Options
    enable_job_exclusive = var.enable_job_exclusive
  }
}

resource "null_resource" "partition" {

  triggers = {
    partition = sha256(jsonencode(local.partition))
  }

  lifecycle {
    precondition {
      condition     = !(length(var.partition_nodeset) == 0 && length(var.partition_nodeset_dyn) == 0 && length(var.partition_nodeset_tpu) == 0)
      error_message = "Partition must contain at least one type of nodeset."
    }
    precondition {
      condition     = ((length(var.partition_nodeset) > 0 || length(var.partition_nodeset_dyn) > 0) && length(var.partition_nodeset_tpu) == 0) || (length(var.partition_nodeset) == 0 && length(var.partition_nodeset_dyn) == 0 && length(var.partition_nodeset_tpu) > 0)
      error_message = "Partition cannot contain TPU and non-TPU nodesets"
    }
  }
}
