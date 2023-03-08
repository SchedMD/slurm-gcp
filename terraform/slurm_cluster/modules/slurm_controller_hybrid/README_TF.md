# slurm_controller_hybrid

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
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 3.53, < 5.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 4.55.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.3.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.1 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.4.3 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cleanup_compute_nodes"></a> [cleanup\_compute\_nodes](#module\_cleanup\_compute\_nodes) | ../slurm_destroy_nodes | n/a |
| <a name="module_cleanup_resource_policies"></a> [cleanup\_resource\_policies](#module\_cleanup\_resource\_policies) | ../slurm_destroy_resource_policies | n/a |
| <a name="module_cleanup_subscriptions"></a> [cleanup\_subscriptions](#module\_cleanup\_subscriptions) | ../slurm_destroy_subscriptions | n/a |
| <a name="module_devel_notify"></a> [devel\_notify](#module\_devel\_notify) | ../slurm_notify_cluster | n/a |
| <a name="module_reconfigure_critical"></a> [reconfigure\_critical](#module\_reconfigure\_critical) | ../slurm_destroy_nodes | n/a |
| <a name="module_reconfigure_notify"></a> [reconfigure\_notify](#module\_reconfigure\_notify) | ../slurm_notify_cluster | n/a |
| <a name="module_reconfigure_partitions"></a> [reconfigure\_partitions](#module\_reconfigure\_partitions) | ../slurm_destroy_nodes | n/a |
| <a name="module_slurm_metadata_devel"></a> [slurm\_metadata\_devel](#module\_slurm\_metadata\_devel) | ../_slurm_metadata_devel | n/a |

## Resources

| Name | Type |
|------|------|
| [google_compute_project_metadata_item.compute_startup_scripts](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_project_metadata_item) | resource |
| [google_compute_project_metadata_item.config](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_project_metadata_item) | resource |
| [google_compute_project_metadata_item.epilog_scripts](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_project_metadata_item) | resource |
| [google_compute_project_metadata_item.prolog_scripts](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_project_metadata_item) | resource |
| [google_pubsub_schema.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_schema) | resource |
| [google_pubsub_topic.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |
| [local_file.config_yaml](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.resume_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.slurmsync_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.startup_sh](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.suspend_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.util_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.setup_hybrid](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_string.topic_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [local_file.resume_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.setup_hybrid_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.slurmsync_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.startup_sh](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.suspend_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.util_py](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloud_parameters"></a> [cloud\_parameters](#input\_cloud\_parameters) | cloud.conf options. | <pre>object({<br>    no_comma_params = bool<br>    resume_rate     = number<br>    resume_timeout  = number<br>    suspend_rate    = number<br>    suspend_timeout = number<br>  })</pre> | <pre>{<br>  "no_comma_params": false,<br>  "resume_rate": 0,<br>  "resume_timeout": 300,<br>  "suspend_rate": 0,<br>  "suspend_timeout": 300<br>}</pre> | no |
| <a name="input_compute_startup_scripts"></a> [compute\_startup\_scripts](#input\_compute\_startup\_scripts) | List of scripts to be ran on compute VM startup. | <pre>list(object({<br>    filename = string<br>    content  = string<br>  }))</pre> | `[]` | no |
| <a name="input_compute_startup_scripts_timeout"></a> [compute\_startup\_scripts\_timeout](#input\_compute\_startup\_scripts\_timeout) | The timeout (seconds) applied to each script in compute\_startup\_scripts. If<br>any script exceeds this timeout, then the instance setup process is considered<br>failed and handled accordingly.<br><br>NOTE: When set to 0, the timeout is considered infinite and thus disabled. | `number` | `300` | no |
| <a name="input_disable_default_mounts"></a> [disable\_default\_mounts](#input\_disable\_default\_mounts) | Disable default global network storage from the controller<br>* /usr/local/etc/slurm<br>* /etc/munge<br>* /home<br>* /apps<br>If these are disabled, the slurm etc and munge dirs must be added manually,<br>or some other mechanism must be used to synchronize the slurm conf files<br>and the munge key across the cluster. | `bool` | `false` | no |
| <a name="input_enable_bigquery_load"></a> [enable\_bigquery\_load](#input\_enable\_bigquery\_load) | Enables loading of cluster job usage into big query.<br><br>NOTE: Requires Google Bigquery API. | `bool` | `false` | no |
| <a name="input_enable_cleanup_compute"></a> [enable\_cleanup\_compute](#input\_enable\_cleanup\_compute) | Enables automatic cleanup of compute nodes and resource policies (e.g.<br>placement groups) managed by this module, when cluster is destroyed.<br><br>NOTE: Requires Python and script dependencies.<br><br>*WARNING*: Toggling this may impact the running workload. Deployed compute nodes<br>may be destroyed and their jobs will be requeued. | `bool` | `false` | no |
| <a name="input_enable_cleanup_subscriptions"></a> [enable\_cleanup\_subscriptions](#input\_enable\_cleanup\_subscriptions) | Enables automatic cleanup of pub/sub subscriptions managed by this module, when<br>cluster is destroyed.<br><br>NOTE: Requires Python and script dependencies.<br><br>*WARNING*: Toggling this may temporarily impact var.enable\_reconfigure behavior. | `bool` | `false` | no |
| <a name="input_enable_devel"></a> [enable\_devel](#input\_enable\_devel) | Enables development mode. Not for production use. | `bool` | `false` | no |
| <a name="input_enable_reconfigure"></a> [enable\_reconfigure](#input\_enable\_reconfigure) | Enables automatic Slurm reconfigure on when Slurm configuration changes (e.g.<br>slurm.conf.tpl, partition details). Compute instances and resource policies<br>(e.g. placement groups) will be destroyed to align with new configuration.<br><br>NOTE: Requires Python and Google Pub/Sub API.<br><br>*WARNING*: Toggling this will impact the running workload. Deployed compute nodes<br>will be destroyed and their jobs will be requeued. | `bool` | `false` | no |
| <a name="input_epilog_scripts"></a> [epilog\_scripts](#input\_epilog\_scripts) | List of scripts to be used for Epilog. Programs for the slurmd to execute<br>on every node when a user's job completes.<br>See https://slurm.schedmd.com/slurm.conf.html#OPT_Epilog. | <pre>list(object({<br>    filename = string<br>    content  = string<br>  }))</pre> | `[]` | no |
| <a name="input_google_app_cred_path"></a> [google\_app\_cred\_path](#input\_google\_app\_cred\_path) | Path to Google Application Credentials. | `string` | `null` | no |
| <a name="input_install_dir"></a> [install\_dir](#input\_install\_dir) | Directory where the hybrid configuration directory will be installed on the<br>on-premise controller (e.g. /etc/slurm/hybrid). This updates the prefix path<br>for the resume and suspend scripts in the generated `cloud.conf` file.<br><br>This variable should be used when the TerraformHost and the SlurmctldHost<br>are different.<br><br>This will default to var.output\_dir if null. | `string` | `null` | no |
| <a name="input_login_network_storage"></a> [login\_network\_storage](#input\_login\_network\_storage) | Storage to mounted on login and controller instances<br>* server\_ip     : Address of the storage server.<br>* remote\_mount  : The location in the remote instance filesystem to mount from.<br>* local\_mount   : The location on the instance filesystem to mount to.<br>* fs\_type       : Filesystem type (e.g. "nfs").<br>* mount\_options : Options to mount with. | <pre>list(object({<br>    server_ip     = string<br>    remote_mount  = string<br>    local_mount   = string<br>    fs_type       = string<br>    mount_options = string<br>  }))</pre> | `[]` | no |
| <a name="input_munge_mount"></a> [munge\_mount](#input\_munge\_mount) | Remote munge mount for compute and login nodes to acquire the munge.key.<br><br>By default, the munge mount server will be assumed to be the<br>`var.slurm_control_host` (or `var.slurm_control_addr` if non-null) when<br>`server_ip=null`. | <pre>object({<br>    server_ip     = string<br>    remote_mount  = string<br>    fs_type       = string<br>    mount_options = string<br>  })</pre> | <pre>{<br>  "fs_type": "nfs",<br>  "mount_options": "",<br>  "remote_mount": "/etc/munge/",<br>  "server_ip": null<br>}</pre> | no |
| <a name="input_network_storage"></a> [network\_storage](#input\_network\_storage) | Storage to mounted on all instances.<br>* server\_ip     : Address of the storage server.<br>* remote\_mount  : The location in the remote instance filesystem to mount from.<br>* local\_mount   : The location on the instance filesystem to mount to.<br>* fs\_type       : Filesystem type (e.g. "nfs").<br>* mount\_options : Options to mount with. | <pre>list(object({<br>    server_ip     = string<br>    remote_mount  = string<br>    local_mount   = string<br>    fs_type       = string<br>    mount_options = string<br>  }))</pre> | `[]` | no |
| <a name="input_output_dir"></a> [output\_dir](#input\_output\_dir) | Directory where this module will write its files to. These files include:<br>cloud.conf; cloud\_gres.conf; config.yaml; resume.py; suspend.py; and util.py. | `string` | `null` | no |
| <a name="input_partitions"></a> [partitions](#input\_partitions) | Cluster partitions as a list. | <pre>list(object({<br>    compute_list = list(string)<br>    partition = object({<br>      enable_job_exclusive    = bool<br>      enable_placement_groups = bool<br>      network_storage = list(object({<br>        server_ip     = string<br>        remote_mount  = string<br>        local_mount   = string<br>        fs_type       = string<br>        mount_options = string<br>      }))<br>      partition_conf = map(string)<br>      partition_name = string<br>      partition_nodes = map(object({<br>        node_count_dynamic_max = number<br>        node_count_static      = number<br>        access_config = list(object({<br>          network_tier = string<br>        }))<br>        bandwidth_tier    = string<br>        enable_spot_vm    = bool<br>        group_name        = string<br>        instance_template = string<br>        node_conf         = map(string)<br>        spot_instance_config = object({<br>          termination_action = string<br>        })<br>      }))<br>      partition_startup_scripts_timeout = number<br>      subnetwork                        = string<br>      zone_target_shape                 = string<br>      zone_policy_allow                 = list(string)<br>      zone_policy_deny                  = list(string)<br>    })<br>  }))</pre> | `[]` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID to create resources in. | `string` | n/a | yes |
| <a name="input_prolog_scripts"></a> [prolog\_scripts](#input\_prolog\_scripts) | List of scripts to be used for Prolog. Programs for the slurmd to execute<br>whenever it is asked to run a job step from a new job allocation.<br>See https://slurm.schedmd.com/slurm.conf.html#OPT_Prolog. | <pre>list(object({<br>    filename = string<br>    content  = string<br>  }))</pre> | `[]` | no |
| <a name="input_slurm_bin_dir"></a> [slurm\_bin\_dir](#input\_slurm\_bin\_dir) | Path to directory of Slurm binary commands (e.g. scontrol, sinfo). If 'null',<br>then it will be assumed that binaries are in $PATH. | `string` | `null` | no |
| <a name="input_slurm_cluster_name"></a> [slurm\_cluster\_name](#input\_slurm\_cluster\_name) | Cluster name, used for resource naming and slurm accounting. | `string` | n/a | yes |
| <a name="input_slurm_control_addr"></a> [slurm\_control\_addr](#input\_slurm\_control\_addr) | The IP address or a name by which the address can be identified.<br><br>This value is passed to slurm.conf such that:<br>SlurmctldHost={var.slurm\_control\_host}\({var.slurm\_control\_addr}\)<br><br>See https://slurm.schedmd.com/slurm.conf.html#OPT_SlurmctldHost | `string` | `null` | no |
| <a name="input_slurm_control_host"></a> [slurm\_control\_host](#input\_slurm\_control\_host) | The short, or long, hostname of the machine where Slurm control daemon is<br>executed (i.e. the name returned by the command "hostname -s").<br><br>This value is passed to slurm.conf such that:<br>SlurmctldHost={var.slurm\_control\_host}\({var.slurm\_control\_addr}\)<br><br>See https://slurm.schedmd.com/slurm.conf.html#OPT_SlurmctldHost | `string` | n/a | yes |
| <a name="input_slurm_control_host_port"></a> [slurm\_control\_host\_port](#input\_slurm\_control\_host\_port) | The port number that the Slurm controller, slurmctld, listens to for work.<br><br>See https://slurm.schedmd.com/slurm.conf.html#OPT_SlurmctldPort | `string` | `null` | no |
| <a name="input_slurm_log_dir"></a> [slurm\_log\_dir](#input\_slurm\_log\_dir) | Directory where Slurm logs to. | `string` | `"/var/log/slurm"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_compute_list"></a> [compute\_list](#output\_compute\_list) | Cluster compute node list. |
| <a name="output_output_dir"></a> [output\_dir](#output\_output\_dir) | Directory where configuration files are written to. |
| <a name="output_partitions"></a> [partitions](#output\_partitions) | Cluster partitions. |
| <a name="output_slurm_cluster_name"></a> [slurm\_cluster\_name](#output\_slurm\_cluster\_name) | Cluster name for resource naming and slurm accounting. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
