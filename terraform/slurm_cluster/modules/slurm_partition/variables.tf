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

variable "project_id" {
  type        = string
  description = "Project ID to create resources in."
}

variable "slurm_cluster_name" {
  type        = string
  description = "Cluster name, used for resource naming and slurm accounting."

  validation {
    condition     = can(regex("^[a-z](?:[a-z0-9]{0,9})$", var.slurm_cluster_name))
    error_message = "Variable 'slurm_cluster_name' must be a match of regex '^[a-z](?:[a-z0-9]{0,9})$'."
  }
}

variable "partition_name" {
  description = "Name of Slurm partition."
  type        = string

  validation {
    condition     = can(regex("^[a-z](?:[a-z0-9]{0,6})$", var.partition_name))
    error_message = "Variable 'partition_name' must be a match of regex '^[a-z](?:[a-z0-9]{0,6})$'."
  }
}

variable "partition_conf" {
  description = <<EOD
Slurm partition configuration as a map.
See https://slurm.schedmd.com/slurm.conf.html#SECTION_PARTITION-CONFIGURATION
EOD
  type        = map(string)
  default     = {}
}

variable "partition_startup_scripts" {
  description = "List of scripts to be ran on compute VM startup."
  type = list(object({
    filename = string
    content  = string
  }))
  default = []
}

variable "partition_nodes" {
  description = <<EOD
Compute nodes contained with this partition.

* node_count_static      : number of persistant nodes.
* node_count_dynamic_max : max number of burstable nodes.
* group_name             : node group unique identifier.
* node_conf              : map of Slurm node line configuration.

See module slurm_instance_template.
EOD
  type = list(object({
    node_count_static      = number
    node_count_dynamic_max = number
    group_name             = string
    node_conf              = map(string)
    additional_disks = list(object({
      disk_name    = string
      device_name  = string
      disk_size_gb = number
      disk_type    = string
      disk_labels  = map(string)
      auto_delete  = bool
      boot         = bool
    }))
    bandwidth_tier         = string
    can_ip_forward         = bool
    disable_smt            = bool
    disk_auto_delete       = bool
    disk_labels            = map(string)
    disk_size_gb           = number
    disk_type              = string
    enable_confidential_vm = bool
    enable_oslogin         = bool
    enable_shielded_vm     = bool
    enable_spot_vm         = bool
    gpu = object({
      count = number
      type  = string
    })
    instance_template   = string
    labels              = map(string)
    machine_type        = string
    metadata            = map(string)
    min_cpu_platform    = string
    on_host_maintenance = string
    preemptible         = bool
    service_account = object({
      email  = string
      scopes = list(string)
    })
    shielded_instance_config = object({
      enable_integrity_monitoring = bool
      enable_secure_boot          = bool
      enable_vtpm                 = bool
    })
    spot_instance_config = object({
      termination_action = string
    })
    source_image_family  = string
    source_image_project = string
    source_image         = string
    tags                 = list(string)
  }))

  validation {
    condition     = length(var.partition_nodes) > 0
    error_message = "Partition must contain nodes."
  }

  validation {
    condition = alltrue([
      for x in var.partition_nodes : can(regex("^[a-z](?:[a-z0-9]{0,5})$", x.group_name))
    ])
    error_message = "Items 'group_name' must be a match of regex '^[a-z](?:[a-z0-9]{0,5})$'."
  }

  validation {
    condition = alltrue([
      for x in var.partition_nodes : x.node_count_static >= 0
    ])
    error_message = "Items 'node_count_static' must be >= 0."
  }

  validation {
    condition = alltrue([
      for x in var.partition_nodes : x.node_count_dynamic_max >= 0
    ])
    error_message = "Items 'node_count_dynamic_max' must be >= 0."
  }

  validation {
    condition = alltrue([
      for x in var.partition_nodes : sum([x.node_count_static, x.node_count_dynamic_max]) > 0
    ])
    error_message = "Sum of 'node_count_static' and 'node_count_dynamic_max' must be > 0."
  }

  validation {
    condition = alltrue([
      for x in var.partition_nodes
      : contains(["STOP", "DELETE"], x.spot_instance_config.termination_action) if x.spot_instance_config != null
    ])
    error_message = "Value of spot_instance_config.termination_action must be one of: STOP; DELETE."
  }

  validation {
    condition = alltrue([
      for x in var.partition_nodes
      : x.enable_spot_vm == x.preemptible if x.enable_spot_vm == true && x.instance_template == null
    ])
    error_message = "Required: preemptible=true when enable_spot_vm=true."
  }
}

variable "subnetwork_project" {
  description = "The project the subnetwork belongs to."
  type        = string
  default     = ""
}

variable "subnetwork" {
  description = "The subnetwork to attach instances to. A self_link is prefered."
  type        = string
  default     = ""
}

variable "region" {
  description = "The region of the subnetwork."
  type        = string
  default     = ""
}

variable "zone_policy_allow" {
  description = <<EOD
Partition nodes will prefer to be created in the listed zones. If a zone appears
in both zone_policy_allow and zone_policy_deny, then zone_policy_deny will take
priority for that zone.
EOD
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for x in var.zone_policy_allow : length(regexall("^[a-z]+-[a-z]+[0-9]-[a-z]$", x)) > 0
    ])
    error_message = "Must be a match of regex '^[a-z]+-[a-z]+[0-9]-[a-z]$'."
  }
}

variable "zone_policy_deny" {
  description = <<EOD
Partition nodes will not be created in the listed zones. If a zone appears in
both zone_policy_allow and zone_policy_deny, then zone_policy_deny will take
priority for that zone.
EOD
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for x in var.zone_policy_deny : length(regexall("^[a-z]+-[a-z]+[0-9]-[a-z]$", x)) > 0
    ])
    error_message = "Must be a match of regex '^[a-z]+-[a-z]+[0-9]-[a-z]$'."
  }
}

variable "enable_job_exclusive" {
  description = <<EOD
Enables job exclusivity. A job will run exclusively on the scheduled nodes.

If `enable_placement_groups=true`, then `enable_job_exclusive=true` will be forced.
EOD
  type        = bool
  default     = false
}

variable "enable_placement_groups" {
  description = <<EOD
Enables job placement groups. Instances will be colocated for a job.

If `enable_placement_groups=true`, then `enable_job_exclusive=true` will be forced.

`enable_placement_groups=false` will be forced when all are not satisfied:
- only compute optimized `machine_type` (C2 or C2D family).
  - See https://cloud.google.com/compute/docs/machine-types
- `node_count_static` == 0
EOD
  type        = bool
  default     = false
}

variable "enable_reconfigure" {
  description = <<EOD
Enables automatic Slurm reconfigure on when Slurm configuration changes (e.g.
slurm.conf.tpl, partition details). Compute instances and resource policies
(e.g. placement groups) will be destroyed to align with new configuration.

NOTE: Requires Python and Google Pub/Sub API.

*WARNING*: Toggling this will impact the running workload. Deployed compute nodes
will be destroyed and their jobs will be requeued.
EOD
  type        = bool
  default     = false
}

variable "network_storage" {
  description = <<EOD
Storage to mounted on all instances in this partition.
* server_ip     : Address of the storage server.
* remote_mount  : The location in the remote instance filesystem to mount from.
* local_mount   : The location on the instance filesystem to mount to.
* fs_type       : Filesystem type (e.g. "nfs").
* mount_options : Raw options to pass to 'mount'.
EOD
  type = list(object({
    server_ip     = string
    remote_mount  = string
    local_mount   = string
    fs_type       = string
    mount_options = string
  }))
  default = []
}
