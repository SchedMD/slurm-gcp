# simple

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
| <a name="module_slurm_cluster"></a> [slurm\_cluster](#module\_slurm\_cluster) | ../../../../../slurm_cluster | n/a |
| <a name="module_slurm_firewall_rules"></a> [slurm\_firewall\_rules](#module\_slurm\_firewall\_rules) | ../../../../../slurm_firewall_rules | n/a |
| <a name="module_slurm_sa_iam"></a> [slurm\_sa\_iam](#module\_slurm\_sa\_iam) | ../../../../../slurm_sa_iam | n/a |

## Resources

| Name | Type |
|------|------|
| [google_compute_subnetwork.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID to create resources in. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The default region to place resources in. | `string` | n/a | yes |
| <a name="input_slurm_cluster_name"></a> [slurm\_cluster\_name](#input\_slurm\_cluster\_name) | Cluster name, used for resource naming. | `string` | `"simple"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_slurm_controller_instance_self_links"></a> [slurm\_controller\_instance\_self\_links](#output\_slurm\_controller\_instance\_self\_links) | Slurm controller instance self\_link. |
| <a name="output_slurm_login_instance_self_links"></a> [slurm\_login\_instance\_self\_links](#output\_slurm\_login\_instance\_self\_links) | Slurm login instance self\_link. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
