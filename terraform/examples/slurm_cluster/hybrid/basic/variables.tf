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

###########
# GENERAL #
###########

variable "project_id" {
  type        = string
  description = "Project ID to create resources in."
}

variable "slurm_cluster_name" {
  type        = string
  description = "Cluster name, used for resource naming."
  default     = "basic"
}

variable "enable_devel" {
  type        = bool
  description = "Enables development process for faster iterations. NOTE: *NOT* intended for production use."
  default     = false
}

variable "enable_reconfigure" {
  description = <<EOD
Enables automatic Slurm reconfigure on cluster delta (e.g. partition).
Configuration files will be regenerated and propagated.

NOTE: Requires Google PubSub API.
EOD
  type        = bool
  default     = true
}

variable "enable_bigquery_load" {
  description = <<EOD
Enables loading of cluster job usage into big query.

NOTE: Requires Google Bigquery API and 'roles/bigquery.dataEditor' on the
controller service account.
EOD
  type        = bool
  default     = false
}

variable "region" {
  type        = string
  description = "The default region to place resources in."
}

#################
# CONFIGURATION #
#################

variable "cloud_parameters" {
  description = "cloud.conf options."
  type = object({
    no_comma_params = bool
    resume_rate     = number
    resume_timeout  = number
    suspend_rate    = number
    suspend_timeout = number
  })
  default = {
    no_comma_params = false
    resume_rate     = 0
    resume_timeout  = 300
    suspend_rate    = 0
    suspend_timeout = 300
  }
}

variable "compute_d" {
  description = "List of scripts to be ran on compute VM startup."
  type = list(object({
    filename = string
    content  = string
  }))
  default = []
}

variable "prolog_d" {
  description = <<EOD
List of scripts to be used for Prolog. Programs for the slurmd to execute
whenever it is asked to run a job step from a new job allocation.
See https://slurm.schedmd.com/slurm.conf.html#OPT_Prolog.
EOD
  type = list(object({
    filename = string
    content  = string
  }))
  default = []
}

variable "epilog_d" {
  description = <<EOD
List of scripts to be used for Epilog. Programs for the slurmd to execute
on every node when a user's job completes.
See https://slurm.schedmd.com/slurm.conf.html#OPT_Epilog.
EOD
  type = list(object({
    filename = string
    content  = string
  }))
  default = []
}

##############
# CONTROLLER #
##############

variable "controller_hybrid_config" {
  description = <<EOD
Creates a hybrid controller with given configuration.

Variables map to:
- [slurm_controller_hybrid](../../../../modules/slurm_controller_hybrid/README_TF.md#inputs)
EOD
  type = object({
    google_app_cred_path = string
    slurm_bin_dir        = string
    slurm_log_dir        = string
    output_dir           = string
  })
  default = {
    google_app_cred_path = null
    slurm_bin_dir        = "/usr/local/bin"
    slurm_log_dir        = "/var/log/slurm"
    output_dir           = "."
  }
}

##############
# PARTITIONS #
##############

variable "partitions" {
  description = <<EOD
Cluster partition configuration as a list.

Variables map to:
- [slurm_partition](../../../../modules/slurm_partition/README_TF.md#inputs)
- [slurm_instance_template](../../../../modules/slurm_instance_template/README_TF.md#inputs)
EOD
  type = list(object({
    enable_job_exclusive    = bool
    enable_placement_groups = bool
    partition_conf          = map(string)
    partition_d = list(object({
      filename = string
      content  = string
    }))
    partition_name = string
    partition_nodes = list(object({
      count_static  = number
      count_dynamic = number
      group_name    = string
      node_conf     = map(string)
      additional_disks = list(object({
        disk_name    = string
        device_name  = string
        disk_size_gb = number
        disk_type    = string
        disk_labels  = map(string)
        auto_delete  = bool
        boot         = bool
      }))
      can_ip_forward         = bool
      disable_smt            = bool
      disk_auto_delete       = bool
      disk_labels            = map(string)
      disk_size_gb           = number
      disk_type              = string
      enable_confidential_vm = bool
      enable_oslogin         = bool
      enable_shielded_vm     = bool
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
      source_image_family  = string
      source_image_project = string
      source_image         = string
      tags                 = list(string)
    }))
    network_storage = list(object({
      local_mount   = string
      fs_type       = string
      server_ip     = string
      remote_mount  = string
      mount_options = string
    }))
    region             = string
    subnetwork_project = string
    subnetwork         = string
    zone_policy_allow  = list(string)
    zone_policy_deny   = list(string)
  }))
  default = []
}
