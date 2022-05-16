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

  destroy_resource_policies = abspath("${local.scripts_dir}/destroy_resource_policies.py")
}

########
# DATA #
########

data "local_file" "destroy_resource_policies" {
  filename = local.destroy_resource_policies
}

#####################################
# DESTROY RESOURCE POLICIES: CREATE #
#####################################

resource "null_resource" "destroy_resource_policies_on_create" {
  count = var.when_destroy ? 0 : 1

  triggers = merge(
    var.triggers,
    {
      scripts_dir        = local.scripts_dir
      script_path        = data.local_file.destroy_resource_policies.filename
      slurm_cluster_name = var.slurm_cluster_name
      partition_name     = var.partition_name
    }
  )

  provisioner "local-exec" {
    working_dir = self.triggers.scripts_dir
    command     = <<EOF
${self.triggers.script_path} \
${self.triggers.partition_name != "" ? "--partition=${self.triggers.partition_name}" : ""} \
${self.triggers.slurm_cluster_name}
EOF
    when        = create
  }
}

######################################
# DESTROY RESOURCE POLICIES: DESTROY #
######################################

resource "null_resource" "destroy_resource_policies_on_destroy" {
  count = var.when_destroy ? 1 : 0

  triggers = merge(
    var.triggers,
    {
      scripts_dir        = local.scripts_dir
      script_path        = data.local_file.destroy_resource_policies.filename
      slurm_cluster_name = var.slurm_cluster_name
      partition_name     = var.partition_name
    }
  )

  provisioner "local-exec" {
    working_dir = self.triggers.scripts_dir
    command     = <<EOF
${self.triggers.script_path} \
${self.triggers.partition_name != "" ? "--partition=${self.triggers.partition_name}" : ""} \
${self.triggers.slurm_cluster_name}
EOF
    when        = destroy
  }
}
