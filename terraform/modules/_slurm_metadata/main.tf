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
  scripts_dir = abspath("${path.module}/../../../scripts")
}

####################
# LOCALS: METADATA #
####################

locals {
  metadata_devel = {
    startup-script = var.enable_devel ? data.local_file.startup[0].content : null
    clustereventd  = var.enable_devel ? data.local_file.clustereventd[0].content : null
    clustersync    = var.enable_devel ? data.local_file.clustersync[0].content : null
    setup-script   = var.enable_devel ? data.local_file.setup[0].content : null
    slurm-resume   = var.enable_devel ? data.local_file.resume[0].content : null
    slurm-suspend  = var.enable_devel ? data.local_file.suspend[0].content : null
    slurmsync      = var.enable_devel ? data.local_file.slurmsync[0].content : null
    util-script    = var.enable_devel ? data.local_file.util[0].content : null
  }
}

#################
# DATA: SCRIPTS #
#################

data "local_file" "startup" {
  count = var.enable_devel ? 1 : 0

  filename = abspath("${local.scripts_dir}/startup.sh")
}

data "local_file" "clustereventd" {
  count = var.enable_devel ? 1 : 0

  filename = abspath("${local.scripts_dir}/clustereventd.py")
}

data "local_file" "clustersync" {
  count = var.enable_devel ? 1 : 0

  filename = abspath("${local.scripts_dir}/clustersync.py")
}

data "local_file" "setup" {
  count = var.enable_devel ? 1 : 0

  filename = abspath("${local.scripts_dir}/setup.py")
}

data "local_file" "resume" {
  count = var.enable_devel ? 1 : 0

  filename = abspath("${local.scripts_dir}/resume.py")
}

data "local_file" "suspend" {
  count = var.enable_devel ? 1 : 0

  filename = abspath("${local.scripts_dir}/suspend.py")
}

data "local_file" "slurmsync" {
  count = var.enable_devel ? 1 : 0

  filename = abspath("${local.scripts_dir}/slurmsync.py")
}

data "local_file" "util" {
  count = var.enable_devel ? 1 : 0

  filename = abspath("${local.scripts_dir}/util.py")
}

############
# METADATA #
############

resource "google_compute_project_metadata_item" "config" {
  project = var.project_id

  key = "${var.cluster_name}-slurm-config"
  value = jsonencode(merge(
    var.metadata,
    local.metadata_devel,
  ))
}
