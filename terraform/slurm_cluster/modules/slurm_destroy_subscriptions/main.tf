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

  destroy_subscriptions = abspath("${local.scripts_dir}/destroy_subscriptions.py")
}

########
# DATA #
########

data "local_file" "destroy_subscriptions" {
  filename = local.destroy_subscriptions
}

#################################
# DESTROY SUBSCRIPTIONS: CREATE #
#################################

resource "null_resource" "destroy_subscriptions_on_create" {
  count = var.when_destroy ? 0 : 1

  triggers = merge(
    var.triggers,
    {
      scripts_dir        = local.scripts_dir
      script_path        = data.local_file.destroy_subscriptions.filename
      slurm_cluster_name = var.slurm_cluster_name
    }
  )

  provisioner "local-exec" {
    working_dir = self.triggers.scripts_dir
    command     = <<EOF
${self.triggers.script_path} '${self.triggers.slurm_cluster_name}'
EOF
    when        = create
  }
}

##################################
# DESTROY SUBSCRIPTIONS: DESTROY #
##################################

resource "null_resource" "destroy_subscriptions_on_destroy" {
  count = var.when_destroy ? 1 : 0

  triggers = merge(
    var.triggers,
    {
      scripts_dir        = local.scripts_dir
      script_path        = data.local_file.destroy_subscriptions.filename
      slurm_cluster_name = var.slurm_cluster_name
    }
  )

  provisioner "local-exec" {
    working_dir = self.triggers.scripts_dir
    command     = <<EOF
${self.triggers.script_path} '${self.triggers.slurm_cluster_name}'
EOF
    when        = destroy
  }
}
