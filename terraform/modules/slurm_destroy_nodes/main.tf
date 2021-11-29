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
  slurm_cluster_id = (
    var.slurm_cluster_id == null
    ? random_uuid.slurm_cluster_id.result
    : var.slurm_cluster_id
  )

  scripts_dir = abspath("${path.module}/../../../scripts")

  destroy_nodes = abspath("${local.scripts_dir}/destroy_nodes.py")
}

########
# DATA #
########

data "local_file" "destroy_nodes" {
  filename = local.destroy_nodes
}

##########
# RANDOM #
##########

resource "random_uuid" "slurm_cluster_id" {
}

#################
# DESTROY NODES #
#################

resource "null_resource" "destroy_nodes" {
  triggers = {
    scripts_dir      = local.scripts_dir
    script_path      = data.local_file.destroy_nodes.filename
    slurm_cluster_id = local.slurm_cluster_id
  }

  provisioner "local-exec" {
    working_dir = self.triggers.scripts_dir
    command     = "${self.triggers.script_path} ${self.triggers.slurm_cluster_id}"
    when        = destroy
  }
}
