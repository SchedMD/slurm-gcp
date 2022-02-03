# Example: Advanced Cloud Slurm Cluster

This example creates a Slurm cluster that is highly configurable through tfvars.
It creates a controller, login nodes, and is capable of bursting out multiple
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
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 3.53, < 5.0 |

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
| <a name="input_cgroup_conf_tpl"></a> [cgroup\_conf\_tpl](#input\_cgroup\_conf\_tpl) | Slurm cgroup.conf template file path. | `string` | `null` | no |
| <a name="input_cloud_parameters"></a> [cloud\_parameters](#input\_cloud\_parameters) | cloud.conf key/value as a map. | `map(string)` | `{}` | no |
| <a name="input_cloudsql"></a> [cloudsql](#input\_cloudsql) | Use this database instead of the one on the controller.<br>* server\_ip : Address of the database server.<br>* user      : The user to access the database as.<br>* password  : The password, given the user, to access the given database. (sensitive)<br>* db\_name   : The database to access. | <pre>object({<br>    server_ip = string<br>    user      = string<br>    password  = string # sensitive<br>    db_name   = string<br>  })</pre> | `null` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster name, used for resource naming. | `string` | `"advanced"` | no |
| <a name="input_compute_d"></a> [compute\_d](#input\_compute\_d) | List of scripts to be ran on compute VM startup. | <pre>list(object({<br>    filename = string<br>    content  = string<br>  }))</pre> | `[]` | no |
| <a name="input_controller_d"></a> [controller\_d](#input\_controller\_d) | List of scripts to be ran on controller VM startup. | <pre>list(object({<br>    filename = string<br>    content  = string<br>  }))</pre> | `[]` | no |
| <a name="input_controller_instance_config"></a> [controller\_instance\_config](#input\_controller\_instance\_config) | Creates a controller instance with given configuration. | <pre>object({<br>    access_config = list(object({<br>      nat_ip       = string<br>      network_tier = string<br>    }))<br>    additional_disks = list(object({<br>      disk_name    = string<br>      device_name  = string<br>      disk_size_gb = number<br>      disk_type    = string<br>      disk_labels  = map(string)<br>      auto_delete  = bool<br>      boot         = bool<br>    }))<br>    can_ip_forward         = bool<br>    disable_smt            = bool<br>    disk_auto_delete       = bool<br>    disk_labels            = map(string)<br>    disk_size_gb           = number<br>    disk_type              = string<br>    enable_confidential_vm = bool<br>    enable_oslogin         = bool<br>    enable_shielded_vm     = bool<br>    gpu = object({<br>      count = number<br>      type  = string<br>    })<br>    instance_template   = string<br>    labels              = map(string)<br>    machine_type        = string<br>    metadata            = map(string)<br>    min_cpu_platform    = string<br>    network_ip          = string<br>    on_host_maintenance = string<br>    preemptible         = bool<br>    region              = string<br>    service_account = object({<br>      email  = string<br>      scopes = list(string)<br>    })<br>    shielded_instance_config = object({<br>      enable_integrity_monitoring = bool<br>      enable_secure_boot          = bool<br>      enable_vtpm                 = bool<br>    })<br>    source_image_family  = string<br>    source_image_project = string<br>    source_image         = string<br>    static_ip            = string<br>    subnetwork_project   = string<br>    subnetwork           = string<br>    tags                 = list(string)<br>    zone                 = string<br>  })</pre> | <pre>{<br>  "access_config": null,<br>  "additional_disks": null,<br>  "can_ip_forward": null,<br>  "disable_smt": null,<br>  "disk_auto_delete": null,<br>  "disk_labels": null,<br>  "disk_size_gb": null,<br>  "disk_type": null,<br>  "enable_confidential_vm": null,<br>  "enable_oslogin": null,<br>  "enable_shielded_vm": null,<br>  "gpu": null,<br>  "instance_template": null,<br>  "labels": null,<br>  "machine_type": null,<br>  "metadata": null,<br>  "min_cpu_platform": null,<br>  "network": null,<br>  "network_ip": null,<br>  "on_host_maintenance": null,<br>  "preemptible": null,<br>  "region": null,<br>  "service_account": null,<br>  "shielded_instance_config": null,<br>  "source_image": null,<br>  "source_image_family": null,<br>  "source_image_project": null,<br>  "static_ip": null,<br>  "subnetwork": null,<br>  "subnetwork_project": null,<br>  "tags": null,<br>  "zone": null<br>}</pre> | no |
| <a name="input_enable_devel"></a> [enable\_devel](#input\_enable\_devel) | Enables development process for faster iterations. NOTE: *NOT* intended for production use. | `bool` | `false` | no |
| <a name="input_epilog_d"></a> [epilog\_d](#input\_epilog\_d) | List of scripts to be used for Epilog. Programs for the slurmd to execute<br>on every node when a user's job completes.<br>See https://slurm.schedmd.com/slurm.conf.html#OPT_Epilog. | <pre>list(object({<br>    filename = string<br>    content  = string<br>  }))</pre> | `[]` | no |
| <a name="input_firewall_network_name"></a> [firewall\_network\_name](#input\_firewall\_network\_name) | Name of the network this set of firewall rules applies to. | `string` | `"default"` | no |
| <a name="input_jwt_key"></a> [jwt\_key](#input\_jwt\_key) | Cluster jwt authentication key. If 'null', then a key will be generated instead. | `string` | `""` | no |
| <a name="input_login_network_storage"></a> [login\_network\_storage](#input\_login\_network\_storage) | Storage to mounted on login and controller instances<br>* server\_ip     : Address of the storage server.<br>* remote\_mount  : The location in the remote instance filesystem to mount from.<br>* local\_mount   : The location on the instance filesystem to mount to.<br>* fs\_type       : Filesystem type (e.g. "nfs").<br>* mount\_options : Options to mount with. | <pre>list(object({<br>    server_ip     = string<br>    remote_mount  = string<br>    local_mount   = string<br>    fs_type       = string<br>    mount_options = string<br>  }))</pre> | `[]` | no |
| <a name="input_login_node_groups"></a> [login\_node\_groups](#input\_login\_node\_groups) | List of slurm login instance definitions. | <pre>list(object({<br>    access_config = list(object({<br>      nat_ip       = string<br>      network_tier = string<br>    }))<br>    additional_disks = list(object({<br>      disk_name    = string<br>      device_name  = string<br>      disk_size_gb = number<br>      disk_type    = string<br>      disk_labels  = map(string)<br>      auto_delete  = bool<br>      boot         = bool<br>    }))<br>    can_ip_forward         = bool<br>    disable_smt            = bool<br>    disk_auto_delete       = bool<br>    disk_labels            = map(string)<br>    disk_size_gb           = number<br>    disk_type              = string<br>    enable_confidential_vm = bool<br>    enable_oslogin         = bool<br>    enable_shielded_vm     = bool<br>    gpu = object({<br>      count = number<br>      type  = string<br>    })<br>    group_name          = string<br>    instance_template   = string<br>    labels              = map(string)<br>    machine_type        = string<br>    metadata            = map(string)<br>    min_cpu_platform    = string<br>    network_ips         = list(string)<br>    num_instances       = number<br>    on_host_maintenance = string<br>    preemptible         = bool<br>    region              = string<br>    service_account = object({<br>      email  = string<br>      scopes = list(string)<br>    })<br>    shielded_instance_config = object({<br>      enable_integrity_monitoring = bool<br>      enable_secure_boot          = bool<br>      enable_vtpm                 = bool<br>    })<br>    source_image_family  = string<br>    source_image_project = string<br>    source_image         = string<br>    static_ips           = list(string)<br>    subnetwork_project   = string<br>    subnetwork           = string<br>    tags                 = list(string)<br>    zone                 = string<br>  }))</pre> | `[]` | no |
| <a name="input_munge_key"></a> [munge\_key](#input\_munge\_key) | Cluster munge authentication key. If 'null', then a key will be generated instead. | `string` | `""` | no |
| <a name="input_network_storage"></a> [network\_storage](#input\_network\_storage) | Storage to mounted on all instances.<br>* server\_ip     : Address of the storage server.<br>* remote\_mount  : The location in the remote instance filesystem to mount from.<br>* local\_mount   : The location on the instance filesystem to mount to.<br>* fs\_type       : Filesystem type (e.g. "nfs").<br>* mount\_options : Options to mount with. | <pre>list(object({<br>    server_ip     = string<br>    remote_mount  = string<br>    local_mount   = string<br>    fs_type       = string<br>    mount_options = string<br>  }))</pre> | `[]` | no |
| <a name="input_partitions"></a> [partitions](#input\_partitions) | Cluster partition configuration as a list. | <pre>list(object({<br>    enable_job_exclusive    = bool<br>    enable_placement_groups = bool<br>    compute_node_groups = list(object({<br>      count_static  = number<br>      count_dynamic = number<br>      group_name    = string<br>      additional_disks = list(object({<br>        disk_name    = string<br>        device_name  = string<br>        disk_size_gb = number<br>        disk_type    = string<br>        disk_labels  = map(string)<br>        auto_delete  = bool<br>        boot         = bool<br>      }))<br>      can_ip_forward         = bool<br>      disable_smt            = bool<br>      disk_auto_delete       = bool<br>      disk_labels            = map(string)<br>      disk_size_gb           = number<br>      disk_type              = string<br>      enable_confidential_vm = bool<br>      enable_oslogin         = bool<br>      enable_shielded_vm     = bool<br>      gpu = object({<br>        count = number<br>        type  = string<br>      })<br>      instance_template   = string<br>      labels              = map(string)<br>      machine_type        = string<br>      metadata            = map(string)<br>      min_cpu_platform    = string<br>      on_host_maintenance = string<br>      preemptible         = bool<br>      service_account = object({<br>        email  = string<br>        scopes = list(string)<br>      })<br>      shielded_instance_config = object({<br>        enable_integrity_monitoring = bool<br>        enable_secure_boot          = bool<br>        enable_vtpm                 = bool<br>      })<br>      source_image_family  = string<br>      source_image_project = string<br>      source_image         = string<br>      tags                 = list(string)<br>    }))<br>    network_storage = list(object({<br>      local_mount   = string<br>      fs_type       = string<br>      server_ip     = string<br>      remote_mount  = string<br>      mount_options = string<br>    }))<br>    partition_name = string<br>    partition_conf = map(string)<br>    partition_d = list(object({<br>      filename = string<br>      content  = string<br>    }))<br>    region             = string<br>    subnetwork_project = string<br>    subnetwork         = string<br>    zone_policy_allow  = list(string)<br>    zone_policy_deny   = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID to create resources in. | `string` | n/a | yes |
| <a name="input_prolog_d"></a> [prolog\_d](#input\_prolog\_d) | List of scripts to be used for Prolog. Programs for the slurmd to execute<br>whenever it is asked to run a job step from a new job allocation.<br>See https://slurm.schedmd.com/slurm.conf.html#OPT_Prolog. | <pre>list(object({<br>    filename = string<br>    content  = string<br>  }))</pre> | `[]` | no |
| <a name="input_region"></a> [region](#input\_region) | The default region to place resources in. | `string` | n/a | yes |
| <a name="input_slurm_conf_tpl"></a> [slurm\_conf\_tpl](#input\_slurm\_conf\_tpl) | Slurm slurm.conf template file path. | `string` | `null` | no |
| <a name="input_slurmdbd_conf_tpl"></a> [slurmdbd\_conf\_tpl](#input\_slurmdbd\_conf\_tpl) | Slurm slurmdbd.conf template file path. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_slurm_cluster_id"></a> [slurm\_cluster\_id](#output\_slurm\_cluster\_id) | Slurm cluster ID. |
| <a name="output_slurm_partitions"></a> [slurm\_partitions](#output\_slurm\_partitions) | Slurm partition details. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
