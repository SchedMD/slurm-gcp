# Module: Slurm Controller Common

This module contains common components for `slurm_controller_*` modules.

**NOTE:** This module is only intended to be used by Slurm modules.

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
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 3.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 3.90.1 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.1.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.1.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_slurm_destroy_nodes"></a> [slurm\_destroy\_nodes](#module\_slurm\_destroy\_nodes) | ../slurm_destroy_nodes | n/a |

## Resources

| Name | Type |
|------|------|
| [google_compute_project_metadata_item.slurm_metadata](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_project_metadata_item) | resource |
| [random_id.jwt_key](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_id.munge_key](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_id.serf_keys](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_string.cluster_name](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [google_compute_instance_template.compute_instance_templates](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_instance_template) | data source |
| [google_compute_subnetwork.partition_subnetworks](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [local_file.clustersync](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.resume](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.serf_events](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.setup](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.slurmsync](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.startup](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.suspend](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.util](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster name, used resource naming and slurm accounting. If 'null', then one will be generated. | `string` | `null` | no |
| <a name="input_compute_d"></a> [compute\_d](#input\_compute\_d) | Path to directory containing user compute provisioning scripts. | `string` | `null` | no |
| <a name="input_enable_devel"></a> [enable\_devel](#input\_enable\_devel) | Enables development mode. Not for production use. | `bool` | `false` | no |
| <a name="input_jwt_key"></a> [jwt\_key](#input\_jwt\_key) | Cluster jwt authentication key. If 'null', then a key will be generated instead. | `string` | `null` | no |
| <a name="input_metadata_compute"></a> [metadata\_compute](#input\_metadata\_compute) | Metadata key/value pairs to make available from within the compute instances. | `map(string)` | `null` | no |
| <a name="input_munge_key"></a> [munge\_key](#input\_munge\_key) | Cluster munge authentication key. If 'null', then a key will be generated instead. | `string` | `null` | no |
| <a name="input_partitions"></a> [partitions](#input\_partitions) | Cluster partitions as a map.<br><br>* subnetwork  : The subnetwork name to create instances in.<br>* region      : The subnetwork region to create instances in.<br>* zone\_policy : Zone location policy for regional bulkInsert.<br><br>* template      : Slurm template key from variable 'compute\_template'.<br>* count\_static  : Number of static nodes. These nodes are exempt from SuspendProgram.<br>* count\_dynamic : Number of dynamic nodes. These nodes are subject to SuspendProgram and ResumeProgram.<br><br>* server\_ip     : Address of the storage server.<br>* remote\_mount  : The location in the remote instance filesystem to mount from.<br>* local\_mount   : The location on the instance filesystem to mount to.<br>* fs\_type       : Filesystem type (e.g. "nfs").<br>* mount\_options : Options to mount with.<br><br>* exclusive        : Enables job exclusivity.<br>* placement\_groups : Enables partition placement groups.<br>* conf             : Slurm partition configurations as a map. | <pre>map(object({<br>    subnetwork  = string<br>    region      = string<br>    zone_policy = map(string)<br>    nodes = list(object({<br>      template      = string<br>      count_static  = number<br>      count_dynamic = number<br>    }))<br>    network_storage = list(object({<br>      server_ip     = string<br>      remote_mount  = string<br>      local_mount   = string<br>      fs_type       = string<br>      mount_options = string<br>    }))<br>    exclusive        = bool<br>    placement_groups = bool<br>    conf             = map(string)<br>  }))</pre> | `{}` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID. | `string` | n/a | yes |
| <a name="input_serf_keys"></a> [serf\_keys](#input\_serf\_keys) | Cluster serf agent keys. If 'null' or '[]', then keys will be generated instead. | `list(string)` | `null` | no |
| <a name="input_slurm_cluster_id"></a> [slurm\_cluster\_id](#input\_slurm\_cluster\_id) | The Cluster ID to use. If 'null', then an ID will be generated. | `string` | `null` | no |
| <a name="input_template_map"></a> [template\_map](#input\_template\_map) | Slurm compute templates as a map. Key=slurm\_template\_name Value=template\_self\_link | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Cluster name for resource naming and slurm accounting. |
| <a name="output_compute_instance_templates"></a> [compute\_instance\_templates](#output\_compute\_instance\_templates) | Compute instance template details. |
| <a name="output_jwt_key"></a> [jwt\_key](#output\_jwt\_key) | Cluster jwt authentication key. |
| <a name="output_munge_key"></a> [munge\_key](#output\_munge\_key) | Cluster munge authentication key. |
| <a name="output_partition_subnetworks"></a> [partition\_subnetworks](#output\_partition\_subnetworks) | Partition subnetwork details. |
| <a name="output_partitions"></a> [partitions](#output\_partitions) | Cluster partitions. |
| <a name="output_serf_keys"></a> [serf\_keys](#output\_serf\_keys) | Cluster serf agent keys. |
| <a name="output_slurm_cluster_id"></a> [slurm\_cluster\_id](#output\_slurm\_cluster\_id) | Cluster ID for cluster resource labeling. |
| <a name="output_template_map"></a> [template\_map](#output\_template\_map) | Compute template map. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
