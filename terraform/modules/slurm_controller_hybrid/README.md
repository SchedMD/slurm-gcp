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
* [**Secret Manager**](https://console.cloud.google.com/security/secret-manager)
  is enabled.

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
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 3.53, < 5.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 4.11.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.1.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.1.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.1.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cleanup"></a> [cleanup](#module\_cleanup) | ../slurm_destroy_nodes | n/a |
| <a name="module_cleanup_resource_policies"></a> [cleanup\_resource\_policies](#module\_cleanup\_resource\_policies) | ../slurm_destroy_resource_policies | n/a |
| <a name="module_delta_compute_list"></a> [delta\_compute\_list](#module\_delta\_compute\_list) | ../slurm_destroy_nodes | n/a |
| <a name="module_delta_critical"></a> [delta\_critical](#module\_delta\_critical) | ../slurm_destroy_nodes | n/a |
| <a name="module_slurm_metadata_devel"></a> [slurm\_metadata\_devel](#module\_slurm\_metadata\_devel) | ../_slurm_metadata_devel | n/a |
| <a name="module_slurm_pubsub"></a> [slurm\_pubsub](#module\_slurm\_pubsub) | terraform-google-modules/pubsub/google | ~> 3.0 |

## Resources

| Name | Type |
|------|------|
| [google_compute_project_metadata_item.compute_d](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_project_metadata_item) | resource |
| [google_compute_project_metadata_item.config](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_project_metadata_item) | resource |
| [google_compute_project_metadata_item.epilog_d](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_project_metadata_item) | resource |
| [google_compute_project_metadata_item.prolog_d](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_project_metadata_item) | resource |
| [google_pubsub_schema.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_schema) | resource |
| [google_pubsub_topic.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |
| [google_secret_manager_secret.munge_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret_version.munge_key_version](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [local_file.config_yaml](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.resume_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.slurmsync_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.suspend_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.util_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.setup_hybrid](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_uuid.slurm_cluster_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) | resource |
| [local_file.resume_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.setup_hybrid_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.slurmsync_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.suspend_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.util_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloud_parameters"></a> [cloud\_parameters](#input\_cloud\_parameters) | cloud.conf options. | <pre>object({<br>    no_comma_params = bool<br>    resume_rate     = number<br>    resume_timeout  = number<br>    suspend_rate    = number<br>    suspend_timeout = number<br>  })</pre> | <pre>{<br>  "no_comma_params": false,<br>  "resume_rate": 0,<br>  "resume_timeout": 300,<br>  "suspend_rate": 0,<br>  "suspend_timeout": 300<br>}</pre> | no |
| <a name="input_compute_d"></a> [compute\_d](#input\_compute\_d) | List of scripts to be ran on compute VM startup. | <pre>list(object({<br>    filename = string<br>    content  = string<br>  }))</pre> | `[]` | no |
| <a name="input_enable_devel"></a> [enable\_devel](#input\_enable\_devel) | Enables development mode. Not for production use. | `bool` | `false` | no |
| <a name="input_epilog_d"></a> [epilog\_d](#input\_epilog\_d) | List of scripts to be used for Epilog. Programs for the slurmd to execute<br>on every node when a user's job completes.<br>See https://slurm.schedmd.com/slurm.conf.html#OPT_Epilog. | <pre>list(object({<br>    filename = string<br>    content  = string<br>  }))</pre> | `[]` | no |
| <a name="input_google_app_cred_path"></a> [google\_app\_cred\_path](#input\_google\_app\_cred\_path) | Path to Google Applicaiton Credentials. | `string` | `null` | no |
| <a name="input_login_network_storage"></a> [login\_network\_storage](#input\_login\_network\_storage) | Storage to mounted on login and controller instances<br>* server\_ip     : Address of the storage server.<br>* remote\_mount  : The location in the remote instance filesystem to mount from.<br>* local\_mount   : The location on the instance filesystem to mount to.<br>* fs\_type       : Filesystem type (e.g. "nfs").<br>* mount\_options : Options to mount with. | <pre>list(object({<br>    server_ip     = string<br>    remote_mount  = string<br>    local_mount   = string<br>    fs_type       = string<br>    mount_options = string<br>  }))</pre> | `[]` | no |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | Metadata key/value pairs. | `map(string)` | `null` | no |
| <a name="input_munge_key"></a> [munge\_key](#input\_munge\_key) | Cluster munge authentication key. | `string` | n/a | yes |
| <a name="input_network_storage"></a> [network\_storage](#input\_network\_storage) | Storage to mounted on all instances.<br>* server\_ip     : Address of the storage server.<br>* remote\_mount  : The location in the remote instance filesystem to mount from.<br>* local\_mount   : The location on the instance filesystem to mount to.<br>* fs\_type       : Filesystem type (e.g. "nfs").<br>* mount\_options : Options to mount with. | <pre>list(object({<br>    server_ip     = string<br>    remote_mount  = string<br>    local_mount   = string<br>    fs_type       = string<br>    mount_options = string<br>  }))</pre> | `[]` | no |
| <a name="input_output_dir"></a> [output\_dir](#input\_output\_dir) | Directory where this module will write its files to. These files include:<br>cloud.conf; gres.conf; config.yaml; resume.py; suspend.py; and util.py. | `string` | `null` | no |
| <a name="input_partitions"></a> [partitions](#input\_partitions) | Cluster partitions as a list. | <pre>list(object({<br>    compute_list = list(string)<br>    partition = object({<br>      enable_job_exclusive    = bool<br>      enable_placement_groups = bool<br>      network_storage = list(object({<br>        server_ip     = string<br>        remote_mount  = string<br>        local_mount   = string<br>        fs_type       = string<br>        mount_options = string<br>      }))<br>      partition_conf = map(string)<br>      partition_name = string<br>      partition_nodes = map(object({<br>        count_dynamic     = number<br>        count_static      = number<br>        group_name        = string<br>        instance_template = string<br>        node_conf         = map(string)<br>      }))<br>      subnetwork        = string<br>      zone_policy_allow = list(string)<br>      zone_policy_deny  = list(string)<br>    })<br>  }))</pre> | `[]` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID to create resources in. | `string` | n/a | yes |
| <a name="input_prolog_d"></a> [prolog\_d](#input\_prolog\_d) | List of scripts to be used for Prolog. Programs for the slurmd to execute<br>whenever it is asked to run a job step from a new job allocation.<br>See https://slurm.schedmd.com/slurm.conf.html#OPT_Prolog. | <pre>list(object({<br>    filename = string<br>    content  = string<br>  }))</pre> | `[]` | no |
| <a name="input_slurm_bin_dir"></a> [slurm\_bin\_dir](#input\_slurm\_bin\_dir) | Path to directroy of Slurm binary commands (e.g. scontrol, sinfo). If 'null',<br>then it will be assumed that binaries are in $PATH. | `string` | `null` | no |
| <a name="input_slurm_cluster_id"></a> [slurm\_cluster\_id](#input\_slurm\_cluster\_id) | The Cluster ID to label resources. If 'null', then an ID will be generated. | `string` | `null` | no |
| <a name="input_slurm_cluster_name"></a> [slurm\_cluster\_name](#input\_slurm\_cluster\_name) | Cluster name, used for resource naming and slurm accounting. | `string` | n/a | yes |
| <a name="input_slurm_log_dir"></a> [slurm\_log\_dir](#input\_slurm\_log\_dir) | Directory where Slurm logs to. | `string` | `"/var/log/slurm"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_compute_list"></a> [compute\_list](#output\_compute\_list) | Cluster compute node list. |
| <a name="output_munge_key"></a> [munge\_key](#output\_munge\_key) | Cluster munge authentication key. |
| <a name="output_output_dir"></a> [output\_dir](#output\_output\_dir) | Directory where configuration files are written to. |
| <a name="output_partitions"></a> [partitions](#output\_partitions) | Cluster partitions. |
| <a name="output_slurm_cluster_id"></a> [slurm\_cluster\_id](#output\_slurm\_cluster\_id) | Cluster ID for cluster resource labeling. |
| <a name="output_slurm_cluster_name"></a> [slurm\_cluster\_name](#output\_slurm\_cluster\_name) | Cluster name for resource naming and slurm accounting. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
