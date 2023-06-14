# slurm_controller_instance

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
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 3.53, < 5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cleanup_compute_nodes"></a> [cleanup\_compute\_nodes](#module\_cleanup\_compute\_nodes) | ../slurm_destroy_nodes | n/a |
| <a name="module_cleanup_resource_policies"></a> [cleanup\_resource\_policies](#module\_cleanup\_resource\_policies) | ../slurm_destroy_resource_policies | n/a |
| <a name="module_slurm_controller_instance"></a> [slurm\_controller\_instance](#module\_slurm\_controller\_instance) | ../_slurm_instance | n/a |

## Resources

| Name | Type |
|------|------|
| [google_secret_manager_secret.cloudsql](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret_iam_member.cloudsql_secret_accessor](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_secret_manager_secret_version.cloudsql_version](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_compute_instance_template.controller_template](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_instance_template) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudsql"></a> [cloudsql](#input\_cloudsql) | Use this database instead of the one on the controller.<br>* server\_ip : Address of the database server.<br>* user      : The user to access the database as.<br>* password  : The password, given the user, to access the given database. (sensitive)<br>* db\_name   : The database to access. | <pre>object({<br>    server_ip = string<br>    user      = string<br>    password  = string # sensitive<br>    db_name   = string<br>  })</pre> | `null` | no |
| <a name="input_enable_cleanup_compute"></a> [enable\_cleanup\_compute](#input\_enable\_cleanup\_compute) | Enables automatic cleanup of compute nodes and resource policies (e.g.<br>placement groups) managed by this module, when cluster is destroyed.<br><br>NOTE: Requires Python and script dependencies.<br><br>*WARNING*: Toggling this may impact the running workload. Deployed compute nodes<br>may be destroyed and their jobs will be requeued. | `bool` | `false` | no |
| <a name="input_enable_public_ip"></a> [enable\_public\_ip](#input\_enable\_public\_ip) | Enables IP address to access the Internet. | `bool` | `false` | no |
| <a name="input_instance_template"></a> [instance\_template](#input\_instance\_template) | Instance template self\_link used to create compute instances. | `string` | n/a | yes |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | Metadata, provided as a map | `map(string)` | `{}` | no |
| <a name="input_network"></a> [network](#input\_network) | Network to deploy to. Only one of network or subnetwork should be specified. | `string` | `""` | no |
| <a name="input_network_tier"></a> [network\_tier](#input\_network\_tier) | The networking tier used for configuring this instance. This field can take the following values: PREMIUM, FIXED\_STANDARD or STANDARD.<br>Ignored if enable\_public\_ip is false. | `string` | `"STANDARD"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID to create resources in. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region where the instances should be created. | `string` | `null` | no |
| <a name="input_slurm_cluster_name"></a> [slurm\_cluster\_name](#input\_slurm\_cluster\_name) | The cluster name, used for resource naming and slurm accounting. | `string` | n/a | yes |
| <a name="input_static_ips"></a> [static\_ips](#input\_static\_ips) | List of static IPs for VM instances. | `list(string)` | `[]` | no |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | Subnet to deploy to. Only one of network or subnetwork should be specified. | `string` | `""` | no |
| <a name="input_subnetwork_project"></a> [subnetwork\_project](#input\_subnetwork\_project) | The project that subnetwork belongs to. | `string` | `""` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | Zone where the instances should be created. If not specified, instances will be<br>spread across available zones in the region. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_logging_filter"></a> [cloud\_logging\_filter](#output\_cloud\_logging\_filter) | Cloud Logging filter to find startup errors. |
| <a name="output_cloudsql_secret"></a> [cloudsql\_secret](#output\_cloudsql\_secret) | Cloudsql secret by URI. |
| <a name="output_instances_self_links"></a> [instances\_self\_links](#output\_instances\_self\_links) | Controller instance resource. |
| <a name="output_slurm_cluster_name"></a> [slurm\_cluster\_name](#output\_slurm\_cluster\_name) | Cluster name for resource naming and slurm accounting. |
| <a name="output_slurm_controller_instance"></a> [slurm\_controller\_instance](#output\_slurm\_controller\_instance) | Controller instance module. |
| <a name="output_slurm_controller_instances"></a> [slurm\_controller\_instances](#output\_slurm\_controller\_instances) | Controller instance resource. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
