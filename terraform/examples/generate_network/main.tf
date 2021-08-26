# Copyright 2021 SchedMD LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module "slurm_cluster" {
  source = "../../../terraform"

  project_id   = var.project_id
  cluster_name = "generate-network"

  network = {
    network = null
    subnets = null
    subnets_spec = [
      {
        cidr   = "10.0.0.0/24"
        region = "us-central1"
      },
    ]
    subnetwork_project = null
  }
}
