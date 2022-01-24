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
  slurm_cluster_id = random_uuid.slurm_cluster_id.result

  partition_map = { for x in var.partitions : x.partition_name => x }

  slurm_cluster_defaults_defaults = {
    additional_disks       = []
    can_ip_forward         = null
    disable_smt            = false
    disk_auto_delete       = true
    disk_labels            = {}
    disk_size_gb           = null
    disk_type              = null
    enable_confidential_vm = false
    enable_oslogin         = true
    enable_shielded_vm     = false
    gpu                    = null
    instance_template      = ""
    labels                 = {}
    machine_type           = "n1-standard-1"
    metadata               = {}
    min_cpu_platform       = null
    network_ip             = ""
    network                = null
    on_host_maintenance    = null
    preemptible            = false
    region                 = null
    service_account = {
      email  = "default"
      scopes = []
    }
    shielded_instance_config = {
      enable_integrity_monitoring = true
      enable_secure_boot          = true
      enable_vtpm                 = true
    }
    source_image_family  = ""
    source_image_project = ""
    source_image         = ""
    subnetwork_project   = null
    subnetwork           = "default"
    tags                 = []
    zone                 = null
  }

  slurm_cluster_defaults = merge(
    local.slurm_cluster_defaults_defaults,
    var.slurm_cluster_defaults,
  )

  controller_instance_config = merge(
    local.slurm_cluster_defaults,
    var.controller_instance_config,
  )

  login_node_groups_defaults = merge(
    local.slurm_cluster_defaults,
    var.login_node_groups_defaults,
  )

  compute_node_groups_defaults = merge(
    local.slurm_cluster_defaults,
    var.compute_node_groups_defaults,
  )

  have_template = (
    lookup(var.controller_instance_config, "instance_template", "") != null
    && lookup(var.controller_instance_config, "instance_template", "") != ""
    ? true
    : false
  )
}
