# Module: Slurm Destroy Nodes

This module creates `null_resource` to manage the task of destroying cluster
compute nodes with the corresponding `slurm_cluster_id` labels.

## Usage

See the [simple](../../examples/slurm_destroy_nodes/simple) example for a usage
example.

## Additional Dependencies

* [**python**](https://www.python.org/) must be installed and in `$PATH` of the
user running `terraform apply`.
  * Required Version: `~3.6, >= 3.6.0, < 4.0.0`
* Python Pip Packages:
  * `addict`

## License

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
Copyright 2021 SchedMD LLC

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
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_local"></a> [local](#provider\_local) | 2.1.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.1.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [null_resource.destroy_nodes_on_create](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.destroy_nodes_on_destroy](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [local_file.destroy_nodes](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_exclude_list"></a> [exclude\_list](#input\_exclude\_list) | Exclude destruction of these compute nodes, by instance name. | `list(string)` | `[]` | no |
| <a name="input_slurm_cluster_id"></a> [slurm\_cluster\_id](#input\_slurm\_cluster\_id) | Destroy compute nodes labeled with this slurm\_cluster\_id. | `string` | n/a | yes |
| <a name="input_target_list"></a> [target\_list](#input\_target\_list) | Target destruction of these compute nodes, by instance name. | `list(string)` | `[]` | no |
| <a name="input_triggers"></a> [triggers](#input\_triggers) | Additional Terraform triggers. | `map(string)` | `{}` | no |
| <a name="input_when_destroy"></a> [when\_destroy](#input\_when\_destroy) | Run only on `terraform destroy`? | `bool` | `false` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
