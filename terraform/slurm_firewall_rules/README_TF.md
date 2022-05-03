# slurm_firewall_rules

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

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_firewall_rules"></a> [firewall\_rules](#module\_firewall\_rules) | terraform-google-modules/network/google//modules/firewall-rules | ~> 4.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | Name of the network this set of firewall rules applies to. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID of the project that holds the network. | `string` | n/a | yes |
| <a name="input_slurm_cluster_name"></a> [slurm\_cluster\_name](#input\_slurm\_cluster\_name) | Cluster name, used for resource naming. | `string` | n/a | yes |
| <a name="input_slurm_depends_on"></a> [slurm\_depends\_on](#input\_slurm\_depends\_on) | Custom terraform dependencies without replacement on delta. This is useful to<br>ensure order of resource creation.<br><br>NOTE: Also see terraform meta-argument 'depends\_on'. | `list(string)` | `[]` | no |
| <a name="input_source_service_accounts"></a> [source\_service\_accounts](#input\_source\_service\_accounts) | If source service accounts are specified, the firewall will apply only to<br>traffic originating from an instance with a service account in this list. Source<br>service accounts cannot be used to control traffic to an instance's external IP<br>address because service accounts are associated with an instance, not an IP<br>address. sourceRanges can be set at the same time as sourceServiceAccounts. If<br>both are set, the firewall will apply to traffic that has source IP address<br>within sourceRanges OR the source IP belongs to an instance with service account<br>listed in sourceServiceAccount. The connection does not need to match both<br>properties for the firewall to apply. sourceServiceAccounts cannot be used at<br>the same time as sourceTags or targetTags. | `list(string)` | `null` | no |
| <a name="input_source_tags"></a> [source\_tags](#input\_source\_tags) | If source tags are specified, the firewall will apply only to traffic with<br>source IP that belongs to a tag listed in source tags. Source tags cannot<br>be used to control traffic to an instance's external IP address. Because tags<br>are associated with an instance, not an IP address. One or both of<br>sourceRanges and sourceTags may be set. If both properties are set, the firewall<br>will apply to traffic that has source IP address within sourceRanges OR the<br>source IP that belongs to a tag listed in the sourceTags property. The<br>connection does not need to match both properties for the firewall to apply. | `list(string)` | `[]` | no |
| <a name="input_target_service_accounts"></a> [target\_service\_accounts](#input\_target\_service\_accounts) | A list of service accounts indicating sets of instances located in the network<br>that may make network connections as specified in allowed[].<br>targetServiceAccounts cannot be used at the same time as targetTags or<br>sourceTags. If neither targetServiceAccounts nor targetTags are specified, the<br>firewall rule applies to all instances on the specified network. | `list(string)` | `null` | no |
| <a name="input_target_tags"></a> [target\_tags](#input\_target\_tags) | A list of instance tags indicating sets of instances located in the network that<br>may make network connections as specified in allowed[]. If no targetTags are<br>specified, the firewall rule applies to all instances on the specified network. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_firewall_rules"></a> [firewall\_rules](#output\_firewall\_rules) | The created firewall rule resources |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
