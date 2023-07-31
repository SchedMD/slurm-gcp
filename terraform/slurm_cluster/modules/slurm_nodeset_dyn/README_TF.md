# slurm_nodeset_dyn

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
| [null_resource.nodeset](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_nodeset_feature"></a> [nodeset\_feature](#input\_nodeset\_feature) | Nodeset feature for dynamic registration. | `string` | n/a | yes |
| <a name="input_nodeset_name"></a> [nodeset\_name](#input\_nodeset\_name) | Name of Slurm nodeset. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_nodeset"></a> [nodeset](#output\_nodeset) | Nodeset details. |
| <a name="output_nodeset_name"></a> [nodeset\_name](#output\_nodeset\_name) | Nodeset name. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
