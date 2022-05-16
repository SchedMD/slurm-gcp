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
}

####################
# LOCALS: METADATA #
####################

locals {
  metadata_devel = {
    startup-script = data.local_file.startup.content
    setup-script   = data.local_file.setup.content
    slurm-resume   = data.local_file.resume.content
    slurm-suspend  = data.local_file.suspend.content
    slurmeventd    = data.local_file.slurmeventd.content
    slurmsync      = data.local_file.slurmsync.content
    util-script    = data.local_file.util.content
    loadbq         = data.local_file.loadbq.content
  }
}

#################
# DATA: SCRIPTS #
#################

data "local_file" "startup" {
  filename = abspath("${local.scripts_dir}/startup.sh")
}

data "local_file" "setup" {
  filename = abspath("${local.scripts_dir}/setup.py")
}

data "local_file" "resume" {
  filename = abspath("${local.scripts_dir}/resume.py")
}

data "local_file" "suspend" {
  filename = abspath("${local.scripts_dir}/suspend.py")
}

data "local_file" "slurmsync" {
  filename = abspath("${local.scripts_dir}/slurmsync.py")
}

data "local_file" "slurmeventd" {
  filename = abspath("${local.scripts_dir}/slurmeventd.py")
}

data "local_file" "util" {
  filename = abspath("${local.scripts_dir}/util.py")
}

data "local_file" "loadbq" {
  filename = abspath("${local.scripts_dir}/load_bq.py")
}

############
# METADATA #
############

resource "google_compute_project_metadata_item" "devel" {
  project = var.project_id

  key   = "${var.slurm_cluster_name}-slurm-devel"
  value = jsonencode(local.metadata_devel)
}
