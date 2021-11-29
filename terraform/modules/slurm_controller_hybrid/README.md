# Module: Slurm Controller Hybrid

This module manages resources required by an on premises Slurm controller to be
able to burst workload to the cloud.

## Usage

See the [simple controller](../../examples/slurm_controller_hybrid/simple)
example or the [simple cluster](../../examples/slurm_cluster/simple_hybrid)
example for usage examples.

## Additional Dependencies

* [**python**](https://www.python.org/) must be installed and in `$PATH` of the
user running `terraform apply`.
  * Required Version: `~3.6, >= 3.6.0, < 4.0.0`

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

| Name | Source | Version |
|------|--------|---------|
| <a name="module_slurm_controller_common"></a> [slurm\_controller\_common](#module\_slurm\_controller\_common) | ../_slurm_controller_common | n/a |

## Resources

| Name | Type |
|------|------|
| [local_file.config_yaml](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.setup_hybrid](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [local_file.setup_hybrid](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloud_parameters"></a> [cloud\_parameters](#input\_cloud\_parameters) | cloud.conf key/value as a map. | `map(string)` | `{}` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster name, used resource naming and slurm accounting. | `string` | `null` | no |
| <a name="input_compute_d"></a> [compute\_d](#input\_compute\_d) | Path to directory containing user compute provisioning scripts. | `string` | `null` | no |
| <a name="input_enable_devel"></a> [enable\_devel](#input\_enable\_devel) | Enables development mode. Not for production use. | `bool` | `false` | no |
| <a name="input_google_app_cred_path"></a> [google\_app\_cred\_path](#input\_google\_app\_cred\_path) | Path to Google Applicaiton Credentials. | `string` | `null` | no |
| <a name="input_jwt_key"></a> [jwt\_key](#input\_jwt\_key) | Cluster jwt authentication key. If 'null', then a key will be generated instead. | `string` | `null` | no |
| <a name="input_login_network_storage"></a> [login\_network\_storage](#input\_login\_network\_storage) | Storage to mounted on login and controller instances | <pre>list(object({<br>    server_ip     = string # description: Address of the storage server.<br>    remote_mount  = string # description: The location in the remote instance filesystem to mount from.<br>    local_mount   = string # description: The location on the instance filesystem to mount to.<br>    fs_type       = string # description: Filesystem type (e.g. "nfs").<br>    mount_options = string # description: Options to mount with.<br>  }))</pre> | `[]` | no |
| <a name="input_metadata_compute"></a> [metadata\_compute](#input\_metadata\_compute) | Metadata key/value pairs to make available from within the compute instances. | `map(string)` | `null` | no |
| <a name="input_munge_key"></a> [munge\_key](#input\_munge\_key) | Cluster munge authentication key. If 'null', then a key will be generated instead. | `string` | `null` | no |
| <a name="input_network_storage"></a> [network\_storage](#input\_network\_storage) | Storage to mounted on all instances | <pre>list(object({<br>    server_ip     = string # description: Address of the storage server.<br>    remote_mount  = string # description: The location in the remote instance filesystem to mount from.<br>    local_mount   = string # description: The location on the instance filesystem to mount to.<br>    fs_type       = string # description: Filesystem type (e.g. "nfs").<br>    mount_options = string # description: Options to mount with.<br>  }))</pre> | `[]` | no |
| <a name="input_output_dir"></a> [output\_dir](#input\_output\_dir) | Directory where this module will write files to. If '' or 'null', then the path<br>to main.tf will be assumed." | `string` | `"."` | no |
| <a name="input_partitions"></a> [partitions](#input\_partitions) | Cluster partitions as a map. | <pre>map(object({<br>    subnetwork  = string      # description: The subnetwork name to create instances in.<br>    region      = string      # description: The subnetwork region to create instances in.<br>    zone_policy = map(string) # description: Zone location policy for regional bulkInsert.<br>    nodes = list(object({<br>      template      = string # description: Slurm template key from variable 'compute_template'.<br>      count_static  = number # description: Number of static nodes. These nodes are exempt from SuspendProgram.<br>      count_dynamic = number # description: Number of dynamic nodes. These nodes are subject to SuspendProgram and ResumeProgram.<br>    }))<br>    network_storage = list(object({<br>      server_ip     = string # description: Address of the storage server.<br>      remote_mount  = string # description: The location in the remote instance filesystem to mount from.<br>      local_mount   = string # description: The location on the instance filesystem to mount to.<br>      fs_type       = string # description: Filesystem type (e.g. "nfs").<br>      mount_options = string # description: Options to mount with.<br>    }))<br>    exclusive        = bool        # description: Enables job exclusivity.<br>    placement_groups = bool        # description: Enables partition placement groups.<br>    conf             = map(string) # description: Slurm partition configurations as a map.<br>  }))</pre> | `{}` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID to create resources in. | `string` | n/a | yes |
| <a name="input_serf_keys"></a> [serf\_keys](#input\_serf\_keys) | Cluster serf agent keys. If 'null' or '[]', then keys will be generated instead. | `list(string)` | `null` | no |
| <a name="input_slurm_bin_dir"></a> [slurm\_bin\_dir](#input\_slurm\_bin\_dir) | Path to directroy of Slurm binary commands (e.g. scontrol, sinfo). If 'null', then it will be assumed that binaries are in $PATH. | `string` | `null` | no |
| <a name="input_slurm_cluster_id"></a> [slurm\_cluster\_id](#input\_slurm\_cluster\_id) | The Cluster ID to use. If 'null', then an ID will be generated. | `string` | `null` | no |
| <a name="input_slurm_log_dir"></a> [slurm\_log\_dir](#input\_slurm\_log\_dir) | Directory where Slurm logs to. | `string` | `"/var/log/slurm"` | no |
| <a name="input_slurm_scripts_dir"></a> [slurm\_scripts\_dir](#input\_slurm\_scripts\_dir) | Path to slurm-gcp scripts. | `string` | `null` | no |
| <a name="input_template_map"></a> [template\_map](#input\_template\_map) | Slurm compute templates as a map. Key=slurm\_template\_name Value=template\_self\_link | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Cluster name for resource naming and slurm accounting. |
| <a name="output_compute_instance_templates"></a> [compute\_instance\_templates](#output\_compute\_instance\_templates) | Compute instance template details. |
| <a name="output_jwt_key"></a> [jwt\_key](#output\_jwt\_key) | Cluster jwt authentication key. |
| <a name="output_munge_key"></a> [munge\_key](#output\_munge\_key) | Cluster munge authentication key. |
| <a name="output_output_dir"></a> [output\_dir](#output\_output\_dir) | Directory where configuration files are written to. |
| <a name="output_partition_subnetworks"></a> [partition\_subnetworks](#output\_partition\_subnetworks) | Partition subnetwork details. |
| <a name="output_partitions"></a> [partitions](#output\_partitions) | Cluster partitions. |
| <a name="output_serf_keys"></a> [serf\_keys](#output\_serf\_keys) | Cluster serf agent keys. |
| <a name="output_slurm_cluster_id"></a> [slurm\_cluster\_id](#output\_slurm\_cluster\_id) | Cluster ID for cluster resource labeling. |
| <a name="output_template_map"></a> [template\_map](#output\_template\_map) | Compute template map. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
