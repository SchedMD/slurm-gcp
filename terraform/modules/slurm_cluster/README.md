# Module: Slurm Cluster

This module creates a Slurm cluster. There are two modes of operation: cloud;
and hybrid. Cloud mode will create a VM controller. Hybrid mode will generate
`cloud.conf` and `gres.conf` files to be included in the on-prem configuration
files.

## Additional Dependencies

* [**python**](https://www.python.org/) must be installed and in `$PATH` of the
user running `terraform apply`.
  * Required Version: `~3.6, >= 3.6.0, < 4.0.0`
* **Private Google Access** must be
[enabled](https://cloud.google.com/vpc/docs/configure-private-google-access)
on the input `subnetwork`.
* [*Shared VPC*](https://cloud.google.com/vpc/docs/shared-vpc) must be enabled
when `subnetwork_project` != `project_id`.

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
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_random"></a> [random](#provider\_random) | 3.1.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_slurm_controller_hybrid"></a> [slurm\_controller\_hybrid](#module\_slurm\_controller\_hybrid) | ../slurm_controller_hybrid | n/a |
| <a name="module_slurm_controller_instance"></a> [slurm\_controller\_instance](#module\_slurm\_controller\_instance) | ../slurm_controller_instance | n/a |
| <a name="module_slurm_controller_template"></a> [slurm\_controller\_template](#module\_slurm\_controller\_template) | ../slurm_controller_template | n/a |
| <a name="module_slurm_login_instance"></a> [slurm\_login\_instance](#module\_slurm\_login\_instance) | ../slurm_login_instance | n/a |
| <a name="module_slurm_login_template"></a> [slurm\_login\_template](#module\_slurm\_login\_template) | ../slurm_login_template | n/a |
| <a name="module_slurm_partition"></a> [slurm\_partition](#module\_slurm\_partition) | ../slurm_partition | n/a |

## Resources

| Name | Type |
|------|------|
| [random_uuid.slurm_cluster_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cgroup_conf_tpl"></a> [cgroup\_conf\_tpl](#input\_cgroup\_conf\_tpl) | Slurm cgroup.conf template file path. | `string` | `null` | no |
| <a name="input_cloud_parameters"></a> [cloud\_parameters](#input\_cloud\_parameters) | cloud.conf key/value as a map. | `map(string)` | `{}` | no |
| <a name="input_cloudsql"></a> [cloudsql](#input\_cloudsql) | Use this database instead of the one on the controller.<br>* server\_ip : Address of the database server.<br>* user      : The user to access the database as.<br>* password  : The password, given the user, to access the given database. (sensitive)<br>* db\_name   : The database to access. | <pre>object({<br>    server_ip = string<br>    user      = string<br>    password  = string # sensitive<br>    db_name   = string<br>  })</pre> | `null` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster name, used for resource naming and slurm accounting. | `string` | n/a | yes |
| <a name="input_compute_d"></a> [compute\_d](#input\_compute\_d) | List of scripts to be ran on compute VM startup. | <pre>list(object({<br>    filename = string<br>    content  = string<br>  }))</pre> | `[]` | no |
| <a name="input_compute_node_groups_defaults"></a> [compute\_node\_groups\_defaults](#input\_compute\_node\_groups\_defaults) | Defaults for compute\_node\_groups in partitions. | `any` | `{}` | no |
| <a name="input_controller_d"></a> [controller\_d](#input\_controller\_d) | List of scripts to be ran on controller VM startup. | <pre>list(object({<br>    filename = string<br>    content  = string<br>  }))</pre> | `[]` | no |
| <a name="input_controller_hybrid_config"></a> [controller\_hybrid\_config](#input\_controller\_hybrid\_config) | Creates a hybrid controller with given configuration.<br>See 'main.tf' for valid keys. | `map(any)` | `{}` | no |
| <a name="input_controller_instance_config"></a> [controller\_instance\_config](#input\_controller\_instance\_config) | Creates a controller instance with given configuration.<br>See 'main.tf' for valid keys. | `any` | `{}` | no |
| <a name="input_enable_devel"></a> [enable\_devel](#input\_enable\_devel) | Enables development mode. Not for production use. | `bool` | `false` | no |
| <a name="input_enable_hybrid"></a> [enable\_hybrid](#input\_enable\_hybrid) | Enables use of hybrid controller mode. When true, controller\_hybrid\_config will<br>be used instead of controller\_instance\_config and will disable login instances. | `bool` | `false` | no |
| <a name="input_jwt_key"></a> [jwt\_key](#input\_jwt\_key) | Cluster jwt authentication key. If 'null', then a key will be generated instead. | `string` | `null` | no |
| <a name="input_login_network_storage"></a> [login\_network\_storage](#input\_login\_network\_storage) | Storage to mounted on login and controller instances<br>* server\_ip     : Address of the storage server.<br>* remote\_mount  : The location in the remote instance filesystem to mount from.<br>* local\_mount   : The location on the instance filesystem to mount to.<br>* fs\_type       : Filesystem type (e.g. "nfs").<br>* mount\_options : Options to mount with. | <pre>list(object({<br>    server_ip     = string<br>    remote_mount  = string<br>    local_mount   = string<br>    fs_type       = string<br>    mount_options = string<br>  }))</pre> | `[]` | no |
| <a name="input_login_node_groups"></a> [login\_node\_groups](#input\_login\_node\_groups) | List of slurm login instance definitions. | `list(any)` | `[]` | no |
| <a name="input_munge_key"></a> [munge\_key](#input\_munge\_key) | Cluster munge authentication key. If 'null', then a key will be generated instead. | `string` | `null` | no |
| <a name="input_network_storage"></a> [network\_storage](#input\_network\_storage) | Storage to mounted on all instances.<br>* server\_ip     : Address of the storage server.<br>* remote\_mount  : The location in the remote instance filesystem to mount from.<br>* local\_mount   : The location on the instance filesystem to mount to.<br>* fs\_type       : Filesystem type (e.g. "nfs").<br>* mount\_options : Options to mount with. | <pre>list(object({<br>    server_ip     = string<br>    remote_mount  = string<br>    local_mount   = string<br>    fs_type       = string<br>    mount_options = string<br>  }))</pre> | `[]` | no |
| <a name="input_partitions"></a> [partitions](#input\_partitions) | Cluster partitions as a list. See module slurm\_partition. | `list(any)` | `[]` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID to create resources in. | `string` | n/a | yes |
| <a name="input_slurm_conf_tpl"></a> [slurm\_conf\_tpl](#input\_slurm\_conf\_tpl) | Slurm slurm.conf template file path. | `string` | `null` | no |
| <a name="input_slurmdbd_conf_tpl"></a> [slurmdbd\_conf\_tpl](#input\_slurmdbd\_conf\_tpl) | Slurm slurmdbd.conf template file path. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_slurm_cluster_id"></a> [slurm\_cluster\_id](#output\_slurm\_cluster\_id) | Slurm cluster ID. |
| <a name="output_slurm_partition"></a> [slurm\_partition](#output\_slurm\_partition) | Slurm partition details. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
