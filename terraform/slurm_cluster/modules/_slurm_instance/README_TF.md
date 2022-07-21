# \_slurm_instance

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
Copyright (C) SchedMD LLC.
Copyright 2018 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 3.43, < 5.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 4.29.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.2.3 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_compute_instance_from_template.slurm_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_from_template) | resource |
| [google_compute_instance_template.base](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_instance_template) | data source |
| [google_compute_zones.available](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_zones) | data source |
| [local_file.startup](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_config"></a> [access\_config](#input\_access\_config) | Access configurations, i.e. IPs via which the VM instance can be accessed via the Internet. | <pre>list(object({<br>    nat_ip       = string<br>    network_tier = string<br>  }))</pre> | `[]` | no |
| <a name="input_add_hostname_suffix"></a> [add\_hostname\_suffix](#input\_add\_hostname\_suffix) | Adds a suffix to the hostname | `bool` | `true` | no |
| <a name="input_hostname"></a> [hostname](#input\_hostname) | Hostname of instances | `string` | `""` | no |
| <a name="input_hostname_suffix_separator"></a> [hostname\_suffix\_separator](#input\_hostname\_suffix\_separator) | Separator character to compose hostname when add\_hostname\_suffix is set to true. | `string` | `"-"` | no |
| <a name="input_instance_template"></a> [instance\_template](#input\_instance\_template) | Instance template self\_link used to create compute instances | `string` | n/a | yes |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | Metadata, provided as a map | `map(string)` | `{}` | no |
| <a name="input_network"></a> [network](#input\_network) | Network to deploy to. Only one of network or subnetwork should be specified. | `string` | `""` | no |
| <a name="input_num_instances"></a> [num\_instances](#input\_num\_instances) | Number of instances to create. This value is ignored if static\_ips is provided. | `number` | `1` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | Region where the instances should be created. | `string` | `null` | no |
| <a name="input_slurm_cluster_name"></a> [slurm\_cluster\_name](#input\_slurm\_cluster\_name) | Cluster name, used for resource naming. | `string` | n/a | yes |
| <a name="input_slurm_depends_on"></a> [slurm\_depends\_on](#input\_slurm\_depends\_on) | Custom terraform dependencies without replacement on delta. This is useful to<br>ensure order of resource creation.<br><br>NOTE: Also see terraform meta-argument 'depends\_on'. | `list(string)` | `[]` | no |
| <a name="input_slurm_instance_role"></a> [slurm\_instance\_role](#input\_slurm\_instance\_role) | Slurm instance type. Must be one of: controller; login; compute. | `string` | `null` | no |
| <a name="input_static_ips"></a> [static\_ips](#input\_static\_ips) | List of static IPs for VM instances | `list(string)` | `[]` | no |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | Subnet to deploy to. Only one of network or subnetwork should be specified. | `string` | `""` | no |
| <a name="input_subnetwork_project"></a> [subnetwork\_project](#input\_subnetwork\_project) | The project that subnetwork belongs to | `string` | `""` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | Zone where the instances should be created. If not specified, instances will be spread across available zones in the region. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_available_zones"></a> [available\_zones](#output\_available\_zones) | List of available zones in region |
| <a name="output_instances_details"></a> [instances\_details](#output\_instances\_details) | List of all details for compute instances |
| <a name="output_instances_self_links"></a> [instances\_self\_links](#output\_instances\_self\_links) | List of self-links for compute instances |
| <a name="output_slurm_instances"></a> [slurm\_instances](#output\_slurm\_instances) | List of all resource objects for compute instances |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
