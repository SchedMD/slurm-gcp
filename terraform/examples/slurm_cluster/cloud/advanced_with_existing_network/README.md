# Example: Advanced Slurm Cluster With Existing Network

This example creates a Slurm cluster that is highly configurable through tfvars.
It creates a controller, login nodes, and is capable of bursting out multiple
compute nodes as defined in partitions. The cluster will attach to an existing
network and subnetwork, including a shared VPC.

## Additional Dependencies

* [**python**](https://www.python.org/) must be installed and in `$PATH` of the
user running `terraform apply`.
  * Required Version: `~3.6, >= 3.6.0, < 4.0.0`
* **Private Google Access** must be
[enabled](https://cloud.google.com/vpc/docs/configure-private-google-access)
on the input `subnetwork`.
* [*Shared VPC*](https://cloud.google.com/vpc/docs/shared-vpc) must be enabled
when `subnetwork_project` != `project_id`.

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

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 4.4.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_slurm_compute_template"></a> [slurm\_compute\_template](#module\_slurm\_compute\_template) | ../../../../modules/slurm_compute_template | n/a |
| <a name="module_slurm_controller_instance"></a> [slurm\_controller\_instance](#module\_slurm\_controller\_instance) | ../../../../modules/slurm_controller_instance | n/a |
| <a name="module_slurm_controller_template"></a> [slurm\_controller\_template](#module\_slurm\_controller\_template) | ../../../../modules/slurm_controller_template | n/a |
| <a name="module_slurm_firewall_rules"></a> [slurm\_firewall\_rules](#module\_slurm\_firewall\_rules) | ../../../../modules/slurm_firewall_rules | n/a |
| <a name="module_slurm_login_instance"></a> [slurm\_login\_instance](#module\_slurm\_login\_instance) | ../../../../modules/slurm_login_instance | n/a |
| <a name="module_slurm_login_template"></a> [slurm\_login\_template](#module\_slurm\_login\_template) | ../../../../modules/slurm_login_template | n/a |
| <a name="module_slurm_partition"></a> [slurm\_partition](#module\_slurm\_partition) | ../../../../modules/slurm_partition | n/a |

## Resources

| Name | Type |
|------|------|
| [google_compute_subnetwork.cluster_subnetwork](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_compute_zones.available](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cgroup_conf_tpl"></a> [cgroup\_conf\_tpl](#input\_cgroup\_conf\_tpl) | Slurm cgroup.conf template file path. | `string` | `null` | no |
| <a name="input_cloud_parameters"></a> [cloud\_parameters](#input\_cloud\_parameters) | cloud.conf key/value as a map. | `map(string)` | `{}` | no |
| <a name="input_cloudsql"></a> [cloudsql](#input\_cloudsql) | Use this database instead of the one on the controller.<br>* server\_ip : Address of the database server.<br>* user      : The user to access the database as.<br>* password  : The password, given the user, to access the given database. (sensitive)<br>* db\_name   : The database to access. | <pre>object({<br>    server_ip = string<br>    user      = string<br>    password  = string # sensitive<br>    db_name   = string<br>  })</pre> | `null` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster name, used for resource naming. | `string` | `"advanced"` | no |
| <a name="input_compute_d"></a> [compute\_d](#input\_compute\_d) | Path to directory containing user compute provisioning scripts. | `string` | `null` | no |
| <a name="input_compute_service_account"></a> [compute\_service\_account](#input\_compute\_service\_account) | Service account to attach to the instance. See https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#service_account. | <pre>object({<br>    email  = string<br>    scopes = set(string)<br>  })</pre> | <pre>{<br>  "email": null,<br>  "scopes": null<br>}</pre> | no |
| <a name="input_compute_templates"></a> [compute\_templates](#input\_compute\_templates) | List of slurm compute instance templates. | <pre>list(object({<br>    alias = string<br><br>    ### network ###<br>    tags = list(string)<br><br>    ### instance ###<br>    machine_type     = string<br>    min_cpu_platform = string<br>    gpu = object({<br>      type  = string<br>      count = number<br>    })<br>    shielded_instance_config = object({<br>      enable_secure_boot          = bool<br>      enable_vtpm                 = bool<br>      enable_integrity_monitoring = bool<br>    })<br>    enable_confidential_vm = bool<br>    enable_shielded_vm     = bool<br>    disable_smt            = bool<br>    preemptible            = bool<br>    labels                 = map(string)<br><br>    ### source image ###<br>    source_image_project = string<br>    source_image_family  = string<br>    source_image         = string<br><br>    ### disk ###<br>    disk_type        = string<br>    disk_size_gb     = number<br>    disk_labels      = map(string)<br>    disk_auto_delete = bool<br>    additional_disks = list(object({<br>      disk_name    = string<br>      device_name  = string<br>      auto_delete  = bool<br>      boot         = bool<br>      disk_size_gb = number<br>      disk_type    = string<br>      disk_labels  = map(string)<br>    }))<br>  }))</pre> | `[]` | no |
| <a name="input_controller_d"></a> [controller\_d](#input\_controller\_d) | Path to directory containing user controller provisioning scripts. | `string` | `null` | no |
| <a name="input_controller_service_account"></a> [controller\_service\_account](#input\_controller\_service\_account) | Service account to attach to the instance. See https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#service_account. | <pre>object({<br>    email  = string<br>    scopes = set(string)<br>  })</pre> | `null` | no |
| <a name="input_controller_template"></a> [controller\_template](#input\_controller\_template) | Slurm controller template. | <pre>object({<br>    ### network ###<br>    tags = list(string)<br><br>    ### instance ###<br>    machine_type     = string<br>    min_cpu_platform = string<br>    gpu = object({<br>      type  = string<br>      count = number<br>    })<br>    shielded_instance_config = object({<br>      enable_secure_boot          = bool<br>      enable_vtpm                 = bool<br>      enable_integrity_monitoring = bool<br>    })<br>    enable_confidential_vm = bool<br>    enable_shielded_vm     = bool<br>    disable_smt            = bool<br>    preemptible            = bool<br>    labels                 = map(string)<br><br>    ### source image ###<br>    source_image_project = string<br>    source_image_family  = string<br>    source_image         = string<br><br>    ### disk ###<br>    disk_type        = string<br>    disk_size_gb     = number<br>    disk_labels      = map(string)<br>    disk_auto_delete = bool<br>    additional_disks = list(object({<br>      disk_name    = string<br>      device_name  = string<br>      auto_delete  = bool<br>      boot         = bool<br>      disk_size_gb = number<br>      disk_type    = string<br>      disk_labels  = map(string)<br>    }))<br>  })</pre> | n/a | yes |
| <a name="input_enable_devel"></a> [enable\_devel](#input\_enable\_devel) | Enables development process for faster iterations. NOTE: *NOT* intended for production use. | `bool` | `false` | no |
| <a name="input_instance_template_network"></a> [instance\_template\_network](#input\_instance\_template\_network) | The network to attach instance templates to. This is required when<br>using a shared VPC configuration (e.g. subnetwork\_project != project\_id). | `string` | `null` | no |
| <a name="input_jwt_key"></a> [jwt\_key](#input\_jwt\_key) | Cluster jwt authentication key. If 'null', then a key will be generated instead. | `string` | `""` | no |
| <a name="input_login"></a> [login](#input\_login) | List of slurm login instance definitions. | <pre>list(object({<br>    alias         = string<br>    num_instances = number<br><br>    ### network ###<br>    tags = list(string)<br><br>    ### instance ###<br>    machine_type     = string<br>    min_cpu_platform = string<br>    gpu = object({<br>      type  = string<br>      count = number<br>    })<br>    shielded_instance_config = object({<br>      enable_secure_boot          = bool<br>      enable_vtpm                 = bool<br>      enable_integrity_monitoring = bool<br>    })<br>    enable_confidential_vm = bool<br>    enable_shielded_vm     = bool<br>    disable_smt            = bool<br>    preemptible            = bool<br>    labels                 = map(string)<br><br>    ### source image ###<br>    source_image_project = string<br>    source_image_family  = string<br>    source_image         = string<br><br>    ### disk ###<br>    disk_type        = string<br>    disk_size_gb     = number<br>    disk_labels      = map(string)<br>    disk_auto_delete = bool<br>    additional_disks = list(object({<br>      disk_name    = string<br>      device_name  = string<br>      auto_delete  = bool<br>      boot         = bool<br>      disk_size_gb = number<br>      disk_type    = string<br>      disk_labels  = map(string)<br>    }))<br>  }))</pre> | `[]` | no |
| <a name="input_login_network_storage"></a> [login\_network\_storage](#input\_login\_network\_storage) | Storage to mounted on login and controller instances<br>* server\_ip     : Address of the storage server.<br>* remote\_mount  : The location in the remote instance filesystem to mount from.<br>* local\_mount   : The location on the instance filesystem to mount to.<br>* fs\_type       : Filesystem type (e.g. "nfs").<br>* mount\_options : Options to mount with. | <pre>list(object({<br>    server_ip     = string<br>    remote_mount  = string<br>    local_mount   = string<br>    fs_type       = string<br>    mount_options = string<br>  }))</pre> | `[]` | no |
| <a name="input_login_service_account"></a> [login\_service\_account](#input\_login\_service\_account) | Service account to attach to the instance. See https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#service_account. | <pre>object({<br>    email  = string<br>    scopes = set(string)<br>  })</pre> | `null` | no |
| <a name="input_munge_key"></a> [munge\_key](#input\_munge\_key) | Cluster munge authentication key. If 'null', then a key will be generated instead. | `string` | `""` | no |
| <a name="input_network_storage"></a> [network\_storage](#input\_network\_storage) | Storage to mounted on all instances.<br>* server\_ip     : Address of the storage server.<br>* remote\_mount  : The location in the remote instance filesystem to mount from.<br>* local\_mount   : The location on the instance filesystem to mount to.<br>* fs\_type       : Filesystem type (e.g. "nfs").<br>* mount\_options : Options to mount with. | <pre>list(object({<br>    server_ip     = string<br>    remote_mount  = string<br>    local_mount   = string<br>    fs_type       = string<br>    mount_options = string<br>  }))</pre> | `[]` | no |
| <a name="input_partitions"></a> [partitions](#input\_partitions) | Cluster partition configuration as a list. | <pre>list(object({<br>    partition_name = string<br>    partition_conf = map(string)<br>    partition_nodes = list(object({<br>      node_group_name            = string<br>      compute_template_alias_ref = string<br>      count_static               = number<br>      count_dynamic              = number<br>    }))<br>    zone_policy_allow = list(string)<br>    zone_policy_deny  = list(string)<br>    network_storage = list(object({<br>      server_ip     = string<br>      remote_mount  = string<br>      local_mount   = string<br>      fs_type       = string<br>      mount_options = string<br>    }))<br>    enable_job_exclusive    = bool<br>    enable_placement_groups = bool<br>  }))</pre> | `[]` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID to create resources in. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The region to place resources in. | `string` | n/a | yes |
| <a name="input_slurm_conf_tpl"></a> [slurm\_conf\_tpl](#input\_slurm\_conf\_tpl) | Slurm slurm.conf template file path. | `string` | `null` | no |
| <a name="input_slurmdbd_conf_tpl"></a> [slurmdbd\_conf\_tpl](#input\_slurmdbd\_conf\_tpl) | Slurm slurmdbd.conf template file path. | `string` | `null` | no |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | The subnetwork name or self\_link to attach instances to. If null, and using a<br>shared VPC configuration (e.g. subnetwork\_project != project\_id) then a<br>subnetwork will be created in the subnetwork\_project. | `string` | `null` | no |
| <a name="input_subnetwork_project"></a> [subnetwork\_project](#input\_subnetwork\_project) | The project the subnetwork belongs to. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Slurm cluster name. |
| <a name="output_partitions"></a> [partitions](#output\_partitions) | Configured Slurm partitions. |
| <a name="output_slurm_cluster_id"></a> [slurm\_cluster\_id](#output\_slurm\_cluster\_id) | Slurm cluster ID. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
