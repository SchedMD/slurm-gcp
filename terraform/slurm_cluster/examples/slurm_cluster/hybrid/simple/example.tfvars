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
# GENERAL #
###########

project_id = "<PROJECT_ID>"

slurm_cluster_name = "simple"

region = "us-central1"

# Network storage
# hybrid requires synchronizing the slurm.conf directory and the munge.key from the controller
disable_default_mounts = true
network_storage = [
  # {
  #   server_ip     = "<storage host>"
  #   remote_mount  = "/home"
  #   local_mount   = "/home"
  #   fs_type       = "nfs"
  #   mount_options = null
  # },
]
