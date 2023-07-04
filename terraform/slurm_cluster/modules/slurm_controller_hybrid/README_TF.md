# slurm_controller_hybrid

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
| <a name="requirement_jinja"></a> [jinja](#requirement\_jinja) | ~> 1.15.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_jinja"></a> [jinja](#provider\_jinja) | ~> 1.15.0 |
| <a name="provider_local"></a> [local](#provider\_local) | ~> 2.0 |
| <a name="provider_null"></a> [null](#provider\_null) | ~> 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cleanup_compute_nodes"></a> [cleanup\_compute\_nodes](#module\_cleanup\_compute\_nodes) | ../slurm_destroy_nodes | n/a |
| <a name="module_cleanup_resource_policies"></a> [cleanup\_resource\_policies](#module\_cleanup\_resource\_policies) | ../slurm_destroy_resource_policies | n/a |

## Resources

| Name | Type |
|------|------|
| [local_file.conf_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.config_yaml](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.resume_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.slurmcmd_service](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.slurmcmd_timer](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.slurmsync_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.startup_sh](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.suspend_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.util_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.setup_hybrid](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [jinja_template.slurmcmd_service](https://registry.terraform.io/providers/NikolaLohinski/jinja/latest/docs/data-sources/template) | data source |
| [jinja_template.slurmcmd_timer](https://registry.terraform.io/providers/NikolaLohinski/jinja/latest/docs/data-sources/template) | data source |
| [local_file.conf_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.resume_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.setup_hybrid_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.slurmsync_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.startup_sh](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.suspend_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.util_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_config"></a> [config](#input\_config) | Cluster configuration. Use 'module.slurm\_files.config' as value. | `any` | n/a | yes |
| <a name="input_enable_cleanup_compute"></a> [enable\_cleanup\_compute](#input\_enable\_cleanup\_compute) | Enables automatic cleanup of compute nodes and resource policies (e.g.<br>placement groups) managed by this module, when cluster is destroyed.<br><br>NOTE: Requires Python and script dependencies.<br><br>*WARNING*: Toggling this may impact the running workload. Deployed compute nodes<br>may be destroyed and their jobs will be requeued. | `bool` | `false` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID to create resources in. | `string` | n/a | yes |
| <a name="input_slurm_cluster_name"></a> [slurm\_cluster\_name](#input\_slurm\_cluster\_name) | Cluster name, used for resource naming and slurm accounting. | `string` | n/a | yes |
| <a name="input_slurm_user"></a> [slurm\_user](#input\_slurm\_user) | Name of the slurm user.<br>Defaults to "slurm". | `string` | `"slurm"` | no |
| <a name="input_slurmcmd_timeout"></a> [slurmcmd\_timeout](#input\_slurmcmd\_timeout) | The wait time between slurmcmd service runs in seconds.<br>It default to 30. | `number` | `30` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_logging_filter"></a> [cloud\_logging\_filter](#output\_cloud\_logging\_filter) | Cloud Logging filter to find startup errors. |
| <a name="output_output_dir"></a> [output\_dir](#output\_output\_dir) | Directory where configuration files are written to. |
| <a name="output_slurm_cluster_name"></a> [slurm\_cluster\_name](#output\_slurm\_cluster\_name) | Cluster name for resource naming and slurm accounting. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
