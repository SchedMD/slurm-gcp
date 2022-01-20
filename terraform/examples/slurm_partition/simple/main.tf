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

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_compute_subnetwork" "default" {
  name   = "default"
  region = var.region
}

module "slurm_partition" {
  source = "../../../modules/slurm_partition"

  partition_name = "default"
  partition_conf = {
    Default = "YES"
  }
  compute_node_groups = [
    {
      count_dynamic = 1
      count_static  = 0
      group_name    = "default"
    },
  ]
  compute_node_groups_defaults = {
    subnetwork = data.google_compute_subnetwork.default.self_link
  }
  cluster_name = var.cluster_name
  project_id   = var.project_id
}
