# Example: Basic Hybrid Slurm Cluster

This example creates a hybrid slurm cluster capable of bursting out multiple
compute nodes from a pre-configured partition.

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

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 4.5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_slurm_cluster"></a> [slurm\_cluster](#module\_slurm\_cluster) | ../../../../modules/slurm_cluster | n/a |
| <a name="module_slurm_firewall_rules"></a> [slurm\_firewall\_rules](#module\_slurm\_firewall\_rules) | ../../../../modules/slurm_firewall_rules | n/a |

## Resources

| Name | Type |
|------|------|
| [google_compute_subnetwork.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster name, used for resource naming. | `string` | `"basic-hybrid"` | no |
| <a name="input_jwt_key"></a> [jwt\_key](#input\_jwt\_key) | Cluster jwt authentication key. If 'null', then a key will be generated instead. | `string` | `""` | no |
| <a name="input_munge_key"></a> [munge\_key](#input\_munge\_key) | Cluster munge authentication key. If 'null', then a key will be generated instead. | `string` | `""` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID to create resources in. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The default region to place resources in. | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
