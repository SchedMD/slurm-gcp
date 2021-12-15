# Example: Basic Hybrid Slurm Cluster

This example creates a basic hybrid cluster. The cluster will create a network
and subnetwork to which resources will be attached.

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
| <a name="module_network"></a> [network](#module\_network) | ../../../../modules/_network | n/a |
| <a name="module_slurm_compute_instance_template"></a> [slurm\_compute\_instance\_template](#module\_slurm\_compute\_instance\_template) | ../../../../modules/slurm_instance_template | n/a |
| <a name="module_slurm_controller_hybrid"></a> [slurm\_controller\_hybrid](#module\_slurm\_controller\_hybrid) | ../../../../modules/slurm_controller_hybrid | n/a |
| <a name="module_slurm_controller_hybrid_template"></a> [slurm\_controller\_hybrid\_template](#module\_slurm\_controller\_hybrid\_template) | ../../../../modules/slurm_instance_template | n/a |
| <a name="module_slurm_firewall_rules"></a> [slurm\_firewall\_rules](#module\_slurm\_firewall\_rules) | ../../../../modules/slurm_firewall_rules | n/a |
| <a name="module_slurm_partition"></a> [slurm\_partition](#module\_slurm\_partition) | ../../../../modules/slurm_partition | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloud_parameters"></a> [cloud\_parameters](#input\_cloud\_parameters) | cloud.conf key/value as a map. | `map(string)` | `{}` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster name, used for resource naming. | `string` | `"simple-hybrid"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID to create resources in. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The region to place resources in. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Slurm cluster name |
| <a name="output_slurm_cluster_id"></a> [slurm\_cluster\_id](#output\_slurm\_cluster\_id) | Slurm cluster ID. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
