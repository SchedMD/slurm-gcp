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

  notify_cluster = abspath("${local.scripts_dir}/notify_cluster.py")
}

########
# DATA #
########

data "local_file" "notify_cluster" {
  filename = local.notify_cluster
}

#########################
# DESTROY NODES: CREATE #
#########################

resource "null_resource" "notify_cluster" {

  triggers = merge(
    var.triggers,
    {
      scripts_dir = local.scripts_dir
      script_path = data.local_file.notify_cluster.filename
      topic       = var.topic
      type        = var.type
    }
  )

  provisioner "local-exec" {
    working_dir = self.triggers.scripts_dir
    command     = "${self.triggers.script_path} --type='${self.triggers.type}' '${self.triggers.topic}'"
    when        = create
  }
}
