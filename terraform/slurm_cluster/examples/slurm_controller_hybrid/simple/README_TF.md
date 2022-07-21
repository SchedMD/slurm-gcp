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
| <a name="provider_random"></a> [random](#provider\_random) | 3.3.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_slurm_controller_hybrid"></a> [slurm\_controller\_hybrid](#module\_slurm\_controller\_hybrid) | ../../../modules/slurm_controller_hybrid | n/a |
| <a name="module_slurm_partition0"></a> [slurm\_partition0](#module\_slurm\_partition0) | ../../../modules/slurm_partition | n/a |
| <a name="module_slurm_partition1"></a> [slurm\_partition1](#module\_slurm\_partition1) | ../../../modules/slurm_partition | n/a |

## Resources

| Name | Type |
|------|------|
| [random_string.slurm_cluster_name](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [google_compute_subnetwork.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID to create resources in. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The region to place resources. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_slurm_controller_hybrid"></a> [slurm\_controller\_hybrid](#output\_slurm\_controller\_hybrid) | Slurm controller hybrid |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
