# slurm_partition

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
Copyright (C) SchedMD LLC.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 3.53, < 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 4.29.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_reconfigure_critical"></a> [reconfigure\_critical](#module\_reconfigure\_critical) | ../slurm_destroy_nodes | n/a |
| <a name="module_reconfigure_node_groups"></a> [reconfigure\_node\_groups](#module\_reconfigure\_node\_groups) | ../slurm_destroy_nodes | n/a |
| <a name="module_reconfigure_placement_groups"></a> [reconfigure\_placement\_groups](#module\_reconfigure\_placement\_groups) | ../slurm_destroy_resource_policies | n/a |
| <a name="module_slurm_compute_template"></a> [slurm\_compute\_template](#module\_slurm\_compute\_template) | ../slurm_instance_template | n/a |

## Resources

| Name | Type |
|------|------|
| [google_compute_project_metadata_item.partition_startup_scripts](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_project_metadata_item) | resource |
| [google_compute_instance_template.group_template](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_instance_template) | data source |
| [google_compute_subnetwork.partition_subnetwork](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_job_exclusive"></a> [enable\_job\_exclusive](#input\_enable\_job\_exclusive) | Enables job exclusivity. A job will run exclusively on the scheduled nodes.<br><br>If `enable_placement_groups=true`, then `enable_job_exclusive=true` will be forced. | `bool` | `false` | no |
| <a name="input_enable_placement_groups"></a> [enable\_placement\_groups](#input\_enable\_placement\_groups) | Enables job placement groups. Instances will be colocated for a job.<br><br>If `enable_placement_groups=true`, then `enable_job_exclusive=true` will be forced.<br><br>`enable_placement_groups=false` will be forced when all are not satisfied:<br>- only compute optimized `machine_type` (C2 or C2D family).<br>  - See https://cloud.google.com/compute/docs/machine-types<br>- `node_count_static` == 0 | `bool` | `false` | no |
| <a name="input_enable_reconfigure"></a> [enable\_reconfigure](#input\_enable\_reconfigure) | Enables automatic Slurm reconfigure on when Slurm configuration changes (e.g.<br>slurm.conf.tpl, partition details). Compute instances and resource policies<br>(e.g. placement groups) will be destroyed to align with new configuration.<br><br>NOTE: Requires Python and Google Pub/Sub API.<br><br>*WARNING*: Toggling this will impact the running workload. Deployed compute nodes<br>will be destroyed and their jobs will be requeued. | `bool` | `false` | no |
| <a name="input_network_storage"></a> [network\_storage](#input\_network\_storage) | Storage to mounted on all instances in this partition.<br>* server\_ip     : Address of the storage server.<br>* remote\_mount  : The location in the remote instance filesystem to mount from.<br>* local\_mount   : The location on the instance filesystem to mount to.<br>* fs\_type       : Filesystem type (e.g. "nfs").<br>* mount\_options : Raw options to pass to 'mount'. | <pre>list(object({<br>    server_ip     = string<br>    remote_mount  = string<br>    local_mount   = string<br>    fs_type       = string<br>    mount_options = string<br>  }))</pre> | `[]` | no |
| <a name="input_partition_conf"></a> [partition\_conf](#input\_partition\_conf) | Slurm partition configuration as a map.<br>See https://slurm.schedmd.com/slurm.conf.html#SECTION_PARTITION-CONFIGURATION | `map(string)` | `{}` | no |
| <a name="input_partition_name"></a> [partition\_name](#input\_partition\_name) | Name of Slurm partition. | `string` | n/a | yes |
| <a name="input_partition_nodes"></a> [partition\_nodes](#input\_partition\_nodes) | Compute nodes contained with this partition.<br><br>* node\_count\_static      : number of persistant nodes.<br>* node\_count\_dynamic\_max : max number of burstable nodes.<br>* group\_name             : node group unique identifier.<br>* node\_conf              : map of Slurm node line configuration.<br><br>See module slurm\_instance\_template. | <pre>list(object({<br>    node_count_static      = number<br>    node_count_dynamic_max = number<br>    group_name             = string<br>    node_conf              = map(string)<br>    additional_disks = list(object({<br>      disk_name    = string<br>      device_name  = string<br>      disk_size_gb = number<br>      disk_type    = string<br>      disk_labels  = map(string)<br>      auto_delete  = bool<br>      boot         = bool<br>    }))<br>    bandwidth_tier         = string<br>    can_ip_forward         = bool<br>    disable_smt            = bool<br>    disk_auto_delete       = bool<br>    disk_labels            = map(string)<br>    disk_size_gb           = number<br>    disk_type              = string<br>    enable_confidential_vm = bool<br>    enable_oslogin         = bool<br>    enable_shielded_vm     = bool<br>    enable_spot_vm         = bool<br>    gpu = object({<br>      count = number<br>      type  = string<br>    })<br>    instance_template   = string<br>    labels              = map(string)<br>    machine_type        = string<br>    metadata            = map(string)<br>    min_cpu_platform    = string<br>    on_host_maintenance = string<br>    preemptible         = bool<br>    service_account = object({<br>      email  = string<br>      scopes = list(string)<br>    })<br>    shielded_instance_config = object({<br>      enable_integrity_monitoring = bool<br>      enable_secure_boot          = bool<br>      enable_vtpm                 = bool<br>    })<br>    spot_instance_config = object({<br>      termination_action = string<br>    })<br>    source_image_family  = string<br>    source_image_project = string<br>    source_image         = string<br>    tags                 = list(string)<br>  }))</pre> | n/a | yes |
| <a name="input_partition_startup_scripts"></a> [partition\_startup\_scripts](#input\_partition\_startup\_scripts) | List of scripts to be ran on compute VM startup. | <pre>list(object({<br>    filename = string<br>    content  = string<br>  }))</pre> | `[]` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID to create resources in. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The region of the subnetwork. | `string` | `""` | no |
| <a name="input_slurm_cluster_name"></a> [slurm\_cluster\_name](#input\_slurm\_cluster\_name) | Cluster name, used for resource naming and slurm accounting. | `string` | n/a | yes |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | The subnetwork to attach instances to. A self\_link is prefered. | `string` | `""` | no |
| <a name="input_subnetwork_project"></a> [subnetwork\_project](#input\_subnetwork\_project) | The project the subnetwork belongs to. | `string` | `""` | no |
| <a name="input_zone_policy_allow"></a> [zone\_policy\_allow](#input\_zone\_policy\_allow) | Partition nodes will prefer to be created in the listed zones. If a zone appears<br>in both zone\_policy\_allow and zone\_policy\_deny, then zone\_policy\_deny will take<br>priority for that zone. | `set(string)` | `[]` | no |
| <a name="input_zone_policy_deny"></a> [zone\_policy\_deny](#input\_zone\_policy\_deny) | Partition nodes will not be created in the listed zones. If a zone appears in<br>both zone\_policy\_allow and zone\_policy\_deny, then zone\_policy\_deny will take<br>priority for that zone. | `set(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_compute_list"></a> [compute\_list](#output\_compute\_list) | List of compute node hostnames. |
| <a name="output_partition"></a> [partition](#output\_partition) | Partition for slurm controller. |
| <a name="output_partition_nodes"></a> [partition\_nodes](#output\_partition\_nodes) | Partition for slurm controller. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
