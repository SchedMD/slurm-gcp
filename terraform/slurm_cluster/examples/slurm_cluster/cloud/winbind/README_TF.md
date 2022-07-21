# winbind

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
| <a name="requirement_template"></a> [template](#requirement\_template) | ~> 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 4.29.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.2.3 |
| <a name="provider_template"></a> [template](#provider\_template) | 2.2.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_slurm_cluster"></a> [slurm\_cluster](#module\_slurm\_cluster) | ../../../../../slurm_cluster | n/a |
| <a name="module_slurm_firewall_rules"></a> [slurm\_firewall\_rules](#module\_slurm\_firewall\_rules) | ../../../../../slurm_firewall_rules | n/a |
| <a name="module_slurm_sa_iam"></a> [slurm\_sa\_iam](#module\_slurm\_sa\_iam) | ../../../../../slurm_sa_iam | n/a |

## Resources

| Name | Type |
|------|------|
| [template_dir.tpl_dir](https://registry.terraform.io/providers/hashicorp/template/latest/docs/resources/dir) | resource |
| [google_compute_subnetwork.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [local_file.winbind_sh](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID to create resources in. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The default region to place resources in. | `string` | n/a | yes |
| <a name="input_slurm_cluster_name"></a> [slurm\_cluster\_name](#input\_slurm\_cluster\_name) | Cluster name, used for resource naming. | `string` | `"winbind"` | no |
| <a name="input_smb_realm"></a> [smb\_realm](#input\_smb\_realm) | SMB Realm | `string` | n/a | yes |
| <a name="input_smb_server"></a> [smb\_server](#input\_smb\_server) | SMB Server | `string` | n/a | yes |
| <a name="input_smb_workgroup"></a> [smb\_workgroup](#input\_smb\_workgroup) | SMB Workgroup | `string` | n/a | yes |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | Subnet to deploy to. Only one of network or subnetwork should be specified. | `string` | `"default"` | no |
| <a name="input_subnetwork_project"></a> [subnetwork\_project](#input\_subnetwork\_project) | The project that subnetwork belongs to. | `string` | `null` | no |
| <a name="input_winbind_join"></a> [winbind\_join](#input\_winbind\_join) | Username and password to authenticate the join with. (e.g. 'Administrator[%Password]') | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_slurm_cluster_name"></a> [slurm\_cluster\_name](#output\_slurm\_cluster\_name) | Slurm cluster name. |
| <a name="output_slurm_partitions"></a> [slurm\_partitions](#output\_slurm\_partitions) | Slurm partition details. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
