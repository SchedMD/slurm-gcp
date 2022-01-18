# Example: Advanced Hybrid Slurm Cluster

This example creates a hybrid Slurm cluster that is highly configurable through
tfvars. It creates a hybrid controller and is capable of bursting out multiple
compute nodes as defined in partitions. A set of firewall rules will be created
to control communication for the cluster.

## Additional Dependencies

* [**python**](https://www.python.org/) must be installed and in `$PATH` of the
user running `terraform apply`.
  * Required Version: `~3.6, >= 3.6.0, < 4.0.0`
* **Private Google Access** must be
[enabled](https://cloud.google.com/vpc/docs/configure-private-google-access)
on the input `subnetwork`.
* [*Shared VPC*](https://cloud.google.com/vpc/docs/shared-vpc) must be enabled
when `subnetwork_project` != `project_id`.
* Munge and JWT key must be readable by the user running `terraform apply`.

## Usage

Modify [example.tfvars](./example.tfvars) with required and desired values.

Then perform the following commands on the root directory:

- `terraform init` to get the plugins
- `terraform plan -var-file=example.tfvars` to see the infrastructure plan
- `terraform apply -var-file=example.tfvars` to apply the infrastructure build
- `terraform destroy -var-file=example.tfvars` to destroy the built infrastructure

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
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 4.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_slurm_cluster"></a> [slurm\_cluster](#module\_slurm\_cluster) | ../../../../modules/slurm_cluster | n/a |
| <a name="module_slurm_firewall_rules"></a> [slurm\_firewall\_rules](#module\_slurm\_firewall\_rules) | ../../../../modules/slurm_firewall_rules | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloud_parameters"></a> [cloud\_parameters](#input\_cloud\_parameters) | cloud.conf key/value as a map. | `map(string)` | `{}` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster name, used for resource naming. | `string` | `"advanced"` | no |
| <a name="input_compute_d"></a> [compute\_d](#input\_compute\_d) | List of scripts to be ran on compute VM startup. | <pre>list(object({<br>    filename = string<br>    content  = string<br>  }))</pre> | `[]` | no |
| <a name="input_compute_node_groups_defaults"></a> [compute\_node\_groups\_defaults](#input\_compute\_node\_groups\_defaults) | Defaults for compute\_node\_groups in partitions.<br><br>Default value priority order:<br>- compute\_node\_groups<br>- compute\_node\_groups\_defaults<br>- slurm\_cluster\_defaults | `any` | `{}` | no |
| <a name="input_controller_hybrid_config"></a> [controller\_hybrid\_config](#input\_controller\_hybrid\_config) | Creates a hybrid controller with given configuration.<br>See 'main.tf' for valid keys. | `map(any)` | `{}` | no |
| <a name="input_enable_devel"></a> [enable\_devel](#input\_enable\_devel) | Enables development process for faster iterations. NOTE: *NOT* intended for production use. | `bool` | `false` | no |
| <a name="input_firewall_network_name"></a> [firewall\_network\_name](#input\_firewall\_network\_name) | Name of the network this set of firewall rules applies to. | `string` | `"default"` | no |
| <a name="input_jwt_key"></a> [jwt\_key](#input\_jwt\_key) | Cluster jwt authentication key. If 'null', then a key will be generated instead. | `string` | `""` | no |
| <a name="input_login_network_storage"></a> [login\_network\_storage](#input\_login\_network\_storage) | Storage to mounted on login and controller instances<br>* server\_ip     : Address of the storage server.<br>* remote\_mount  : The location in the remote instance filesystem to mount from.<br>* local\_mount   : The location on the instance filesystem to mount to.<br>* fs\_type       : Filesystem type (e.g. "nfs").<br>* mount\_options : Options to mount with. | <pre>list(object({<br>    server_ip     = string<br>    remote_mount  = string<br>    local_mount   = string<br>    fs_type       = string<br>    mount_options = string<br>  }))</pre> | `[]` | no |
| <a name="input_munge_key"></a> [munge\_key](#input\_munge\_key) | Cluster munge authentication key. If 'null', then a key will be generated instead. | `string` | `""` | no |
| <a name="input_network_storage"></a> [network\_storage](#input\_network\_storage) | Storage to mounted on all instances.<br>* server\_ip     : Address of the storage server.<br>* remote\_mount  : The location in the remote instance filesystem to mount from.<br>* local\_mount   : The location on the instance filesystem to mount to.<br>* fs\_type       : Filesystem type (e.g. "nfs").<br>* mount\_options : Options to mount with. | <pre>list(object({<br>    server_ip     = string<br>    remote_mount  = string<br>    local_mount   = string<br>    fs_type       = string<br>    mount_options = string<br>  }))</pre> | `[]` | no |
| <a name="input_partitions"></a> [partitions](#input\_partitions) | Cluster partition configuration as a list. | `list(any)` | `[]` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID to create resources in. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The default region to place resources in. | `string` | n/a | yes |
| <a name="input_slurm_cluster_defaults"></a> [slurm\_cluster\_defaults](#input\_slurm\_cluster\_defaults) | Defaults for cluster controller, login, and compute nodes.<br><br>Controller node default value priority order:<br>- controller\_instance\_config<br>- slurm\_cluster\_defaults<br><br>Login node default value priority order:<br>- login\_node\_groups<br>- login\_node\_groups\_defaults<br>- slurm\_cluster\_defaults<br><br>Compute node default value priority order:<br>- compute\_node\_groups<br>- compute\_node\_groups\_defaults<br>- slurm\_cluster\_defaults | `any` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_slurm_cluster_id"></a> [slurm\_cluster\_id](#output\_slurm\_cluster\_id) | Slurm cluster ID. |
| <a name="output_slurm_partitions"></a> [slurm\_partitions](#output\_slurm\_partitions) | Slurm partition details. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
