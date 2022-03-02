# Example: Slurm Blank Template

This exmaple creates a blank slurm instance template. It can be used by:

- [slurm_controller_instance](../../../modules/slurm_controller_instance)
- [slurm_login_instance](../../../modules/slurm_login_instance)
- [slurm_partition](../../../modules/slurm_partition)

## Usage

Modify [example.tfvars](./example.tfvars) with required and desired values.

Then perform the following commands on the root directory:

- `terraform init` to get the plugins
- `terraform plan -var-file=example.tfvars` to see the infrastructure plan
- `terraform apply -var-file=example.tfvars` to apply the infrastructure build
- `terraform destroy -var-file=example.tfvars` to destroy the built infrastructure
