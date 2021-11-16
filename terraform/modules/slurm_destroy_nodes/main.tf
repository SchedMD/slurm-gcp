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
  cluster_id = (
    var.cluster_id == null
    ? random_uuid.cluster_id.result
    : var.cluster_id
  )

  scripts_dir = "${path.module}/../../../scripts"
}

##########
# RANDOM #
##########

resource "random_uuid" "cluster_id" {
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
