# slurm_nodeset

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
| <a name="provider_google"></a> [google](#provider\_google) | >= 3.53, < 5.0 |
| <a name="provider_null"></a> [null](#provider\_null) | ~> 3.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [null_resource.nodeset](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [google_compute_zones.available](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bandwidth_tier"></a> [bandwidth\_tier](#input\_bandwidth\_tier) | Tier 1 bandwidth increases the maximum egress bandwidth for VMs.<br>Using the `virtio_enabled` setting will only enable VirtioNet and will not enable TIER\_1.<br>Using the `tier_1_enabled` setting will enable both gVNIC and TIER\_1 higher bandwidth networking.<br>Using the `gvnic_enabled` setting will only enable gVNIC and will not enable TIER\_1.<br>Note that TIER\_1 only works with specific machine families & shapes and must be using an image that supports gVNIC. See [official docs](https://cloud.google.com/compute/docs/networking/configure-vm-with-high-bandwidth-configuration) for more details. | `string` | `"platform_default"` | no |
| <a name="input_enable_placement"></a> [enable\_placement](#input\_enable\_placement) | Enables compact placement policy for instances.<br>Use compact policies when you want VMs to be located close to each other for low network latency between the VMs.<br>See https://cloud.google.com/compute/docs/instances/define-instance-placement for details. | `bool` | `false` | no |
| <a name="input_enable_public_ip"></a> [enable\_public\_ip](#input\_enable\_public\_ip) | Enables IP address to access the Internet. | `bool` | `false` | no |
| <a name="input_instance_template_self_link"></a> [instance\_template\_self\_link](#input\_instance\_template\_self\_link) | Instance template self\_link used to create compute instances. | `string` | n/a | yes |
| <a name="input_network_tier"></a> [network\_tier](#input\_network\_tier) | The networking tier used for configuring this instance. This field can take the following values: PREMIUM, FIXED\_STANDARD or STANDARD.<br>Ignored if enable\_public\_ip is false. | `string` | `"STANDARD"` | no |
| <a name="input_node_conf"></a> [node\_conf](#input\_node\_conf) | Slurm node configuration, as a map.<br>See https://slurm.schedmd.com/slurm.conf.html#SECTION_NODE-CONFIGURATION for details. | `map(string)` | `{}` | no |
| <a name="input_node_count_dynamic_max"></a> [node\_count\_dynamic\_max](#input\_node\_count\_dynamic\_max) | Maximum number of nodes allowed in this partition to be created dynamically. | `number` | `0` | no |
| <a name="input_node_count_static"></a> [node\_count\_static](#input\_node\_count\_static) | Number of nodes to be statically created. | `number` | `0` | no |
| <a name="input_nodeset_name"></a> [nodeset\_name](#input\_nodeset\_name) | Name of Slurm nodeset. | `string` | n/a | yes |
| <a name="input_subnetwork_self_link"></a> [subnetwork\_self\_link](#input\_subnetwork\_self\_link) | The subnetwork self\_link to attach instances to. | `string` | n/a | yes |
| <a name="input_zone_target_shape"></a> [zone\_target\_shape](#input\_zone\_target\_shape) | Strategy for distributing VMs across zones in a region.<br>ANY<br>  GCE picks zones for creating VM instances to fulfill the requested number of VMs<br>  within present resource constraints and to maximize utilization of unused zonal<br>  reservations.<br>ANY\_SINGLE\_ZONE (default)<br>  GCE always selects a single zone for all the VMs, optimizing for resource quotas,<br>  available reservations and general capacity.<br>BALANCED<br>  GCE prioritizes acquisition of resources, scheduling VMs in zones where resources<br>  are available while distributing VMs as evenly as possible across allowed zones<br>  to minimize the impact of zonal failure. | `string` | `"ANY_SINGLE_ZONE"` | no |
| <a name="input_zones"></a> [zones](#input\_zones) | Nodes will only be created in the listed zones.<br>If none are given, all available zones for the region will be allowed.<br>NOTE: Machine Type and GPU availability may vary with zone. | `set(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_nodeset"></a> [nodeset](#output\_nodeset) | Nodeset details. |
| <a name="output_nodeset_name"></a> [nodeset\_name](#output\_nodeset\_name) | Nodeset name. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
