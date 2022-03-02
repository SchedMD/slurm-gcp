# Example: Slurm Controller Template

This exmaple creates a slurm controller instance template intended to be used by
the [slurm_controller_instance](../../../modules/slurm_controller_instance).

## Usage

Modify [example.tfvars](./example.tfvars) with required and desired values.

Then perform the following commands on the root directory:

- `terraform init` to get the plugins
- `terraform plan -var-file=example.tfvars` to see the infrastructure plan
- `terraform apply -var-file=example.tfvars` to apply the infrastructure build
- `terraform destroy -var-file=example.tfvars` to destroy the built infrastructure
