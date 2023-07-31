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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.2 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 3.53, < 5.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_null"></a> [null](#provider\_null) | ~> 3.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [null_resource.partition](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_default"></a> [default](#input\_default) | If this is true, jobs submitted without a partition specification will utilize this partition.<br>This sets 'Default' in partition\_conf.<br>See https://slurm.schedmd.com/slurm.conf.html#OPT_Default for details. | `bool` | `false` | no |
| <a name="input_enable_job_exclusive"></a> [enable\_job\_exclusive](#input\_enable\_job\_exclusive) | Enables job exclusivity. A job will run exclusively on the scheduled nodes. | `bool` | `false` | no |
| <a name="input_network_storage"></a> [network\_storage](#input\_network\_storage) | Storage to mounted on all instances in this partition.<br>* server\_ip     : Address of the storage server.<br>* remote\_mount  : The location in the remote instance filesystem to mount from.<br>* local\_mount   : The location on the instance filesystem to mount to.<br>* fs\_type       : Filesystem type (e.g. "nfs").<br>* mount\_options : Raw options to pass to 'mount'. | <pre>list(object({<br>    server_ip     = string<br>    remote_mount  = string<br>    local_mount   = string<br>    fs_type       = string<br>    mount_options = string<br>  }))</pre> | `[]` | no |
| <a name="input_partition_conf"></a> [partition\_conf](#input\_partition\_conf) | Slurm partition configuration as a map.<br>See https://slurm.schedmd.com/slurm.conf.html#SECTION_PARTITION-CONFIGURATION | `map(string)` | `{}` | no |
| <a name="input_partition_name"></a> [partition\_name](#input\_partition\_name) | Name of Slurm partition. | `string` | n/a | yes |
| <a name="input_partition_nodeset"></a> [partition\_nodeset](#input\_partition\_nodeset) | Slurm nodesets by name, as a list of string. | `set(string)` | `[]` | no |
| <a name="input_partition_nodeset_dyn"></a> [partition\_nodeset\_dyn](#input\_partition\_nodeset\_dyn) | Slurm nodesets (dynamic) by name, as a list of string. | `set(string)` | `[]` | no |
| <a name="input_partition_nodeset_tpu"></a> [partition\_nodeset\_tpu](#input\_partition\_nodeset\_tpu) | Slurm nodesets (tpu) by name, as a list of string. | `set(string)` | `[]` | no |
| <a name="input_resume_timeout"></a> [resume\_timeout](#input\_resume\_timeout) | Maximum time permitted (in seconds) between when a node resume request is issued and when the node is actually available for use.<br>If null is given, then a smart default will be chosen depending on nodesets in partition.<br>This sets 'ResumeTimeout' in partition\_conf.<br>See https://slurm.schedmd.com/slurm.conf.html#OPT_ResumeTimeout_1 for details. | `number` | `300` | no |
| <a name="input_suspend_time"></a> [suspend\_time](#input\_suspend\_time) | Nodes which remain idle or down for this number of seconds will be placed into power save mode by SuspendProgram.<br>This sets 'SuspendTime' in partition\_conf.<br>See https://slurm.schedmd.com/slurm.conf.html#OPT_SuspendTime_1 for details.<br>NOTE: use value -1 to exclude partition from suspend. | `number` | `300` | no |
| <a name="input_suspend_timeout"></a> [suspend\_timeout](#input\_suspend\_timeout) | Maximum time permitted (in seconds) between when a node suspend request is issued and when the node is shutdown.<br>If null is given, then a smart default will be chosen depending on nodesets in partition.<br>This sets 'SuspendTimeout' in partition\_conf.<br>See https://slurm.schedmd.com/slurm.conf.html#OPT_SuspendTimeout_1 for details. | `number` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_partition"></a> [partition](#output\_partition) | Partition for slurm controller. |
| <a name="output_partition_name"></a> [partition\_name](#output\_partition\_name) | Partition for slurm controller. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
