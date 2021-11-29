# Example: Complex Hybrid Slurm Cluster

This example creates a Slurm cluster that is highly configurable through tfvars.

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
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 3.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_network"></a> [network](#module\_network) | ../../../modules/_network | n/a |
| <a name="module_slurm_compute_instance_templates"></a> [slurm\_compute\_instance\_templates](#module\_slurm\_compute\_instance\_templates) | ../../../modules/slurm_instance_template | n/a |
| <a name="module_slurm_controller_hybrid"></a> [slurm\_controller\_hybrid](#module\_slurm\_controller\_hybrid) | ../../../modules/slurm_controller_hybrid | n/a |
| <a name="module_slurm_firewall_rules"></a> [slurm\_firewall\_rules](#module\_slurm\_firewall\_rules) | ../../../modules/slurm_firewall_rules | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster name. Used to name resources. | `string` | `"complex"` | no |
| <a name="input_compute_service_account"></a> [compute\_service\_account](#input\_compute\_service\_account) | Service account to attach to the instance. See https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#service_account. | <pre>object({<br>    email  = string<br>    scopes = set(string)<br>  })</pre> | <pre>{<br>  "email": null,<br>  "scopes": null<br>}</pre> | no |
| <a name="input_compute_templates"></a> [compute\_templates](#input\_compute\_templates) | Maps slurm compute template name to instance definition. | <pre>map(object({<br>    ### network ###<br>    tags = list(string)<br><br>    ### instance ###<br>    machine_type     = string<br>    min_cpu_platform = string<br>    gpu = object({<br>      type  = string<br>      count = number<br>    })<br>    shielded_instance_config = object({<br>      enable_secure_boot          = bool<br>      enable_vtpm                 = bool<br>      enable_integrity_monitoring = bool<br>    })<br>    enable_confidential_vm = bool<br>    enable_shielded_vm     = bool<br>    disable_smt            = bool<br>    preemptible            = bool<br>    labels                 = map(string)<br><br>    ### source image ###<br>    source_image_project = string<br>    source_image_family  = string<br>    source_image         = string<br><br>    ### disk ###<br>    disk_type        = string<br>    disk_size_gb     = number<br>    disk_labels      = map(string)<br>    disk_auto_delete = bool<br>    additional_disks = list(object({<br>      disk_name    = string<br>      device_name  = string<br>      auto_delete  = bool<br>      boot         = bool<br>      disk_size_gb = number<br>      disk_type    = string<br>      disk_labels  = map(string)<br>    }))<br>  }))</pre> | `{}` | no |
| <a name="input_config"></a> [config](#input\_config) | General cluster configuration. | <pre>object({<br>    cloudsql = object({<br>      server_ip = string<br>      user      = string<br>      password  = string # (sensitive)<br>      db_name   = string<br>    })<br>    jwt_key   = string<br>    munge_key = string<br>    serf_keys = list(string)<br><br>    network_storage = list(object({<br>      server_ip     = string<br>      remote_mount  = string<br>      local_mount   = string<br>      fs_type       = string<br>      mount_options = string<br>    }))<br>    login_network_storage = list(object({<br>      server_ip     = string<br>      remote_mount  = string<br>      local_mount   = string<br>      fs_type       = string<br>      mount_options = string<br>    }))<br><br>    compute_d = string<br><br>    slurm_bin_dir = string<br>    slurm_log_dir = string<br><br>    cloud_parameters = map(string)<br>  })</pre> | <pre>{<br>  "cloud_parameters": {},<br>  "cloudsql": null,<br>  "compute_d": null,<br>  "jwt_key": null,<br>  "login_network_storage": null,<br>  "munge_key": null,<br>  "network_storage": null,<br>  "serf_keys": null,<br>  "slurm_bin_dir": null,<br>  "slurm_log_dir": null<br>}</pre> | no |
| <a name="input_enable_devel"></a> [enable\_devel](#input\_enable\_devel) | Enables development process for faster iterations. NOTE: *NOT* intended for production use. | `bool` | `false` | no |
| <a name="input_partitions"></a> [partitions](#input\_partitions) | Cluster partition configuration. | <pre>map(object({<br>    zone_policy = map(string)<br>    nodes = list(object({<br>      template      = string<br>      count_static  = number<br>      count_dynamic = number<br>    }))<br>    network_storage = list(object({<br>      server_ip     = string<br>      remote_mount  = string<br>      local_mount   = string<br>      fs_type       = string<br>      mount_options = string<br>    }))<br>    exclusive        = bool<br>    placement_groups = bool<br>    conf             = map(string)<br>  }))</pre> | `{}` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID to create resources in. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The region to place resources in. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Slurm cluster name. |
| <a name="output_partitions"></a> [partitions](#output\_partitions) | Configured Slurm partitions. |
| <a name="output_slurm_cluster_id"></a> [slurm\_cluster\_id](#output\_slurm\_cluster\_id) | Slurm cluster ID. |
| <a name="output_template_map"></a> [template\_map](#output\_template\_map) | Slurm compute isntance template map. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
