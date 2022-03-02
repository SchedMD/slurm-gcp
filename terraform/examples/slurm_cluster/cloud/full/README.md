# Example: Full Cloud Slurm Cluster

This example minamally creates all required components to support a Slurm cluster
while being highly configurable through tfvars. This includes: a VPC/Network;
an attached subnetwork; a slurm controller instance; defined login instances;
defined compute instances from partitions; and instance service accounts for each
slurm instance, with minimal roles and scopes.

## Additional Dependencies

- [**python**](https://www.python.org/) must be installed and in `$PATH` of the
  user running `terraform apply`.
  - Required Version: `~3.6, >= 3.6.0, < 4.0.0`
- [**Secret Manager**](https://console.cloud.google.com/security/secret-manager)
  is enabled.

## Usage

Modify [example.tfvars](./example.tfvars) with required and desired values.

Then perform the following commands on the root directory:

- `terraform init` to get the plugins
- `terraform plan -var-file=example.tfvars` to see the infrastructure plan
- `terraform apply -var-file=example.tfvars` to apply the infrastructure build
- `terraform destroy -var-file=example.tfvars` to destroy the built infrastructure
