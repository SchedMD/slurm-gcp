# Example: Basic Cloud Slurm Cluster

This example creates a Slurm cluster that is highly configurable through tfvars.
It creates a controller, login nodes, and is capable of bursting out multiple
compute nodes as defined in partitions. A set of firewall rules will be created
to control communication for the cluster.

## Additional Dependencies

- [**python**](https://www.python.org/) must be installed and in `$PATH` of the
  user running `terraform apply`.
  - Required Version: `~3.6, >= 3.6.0, < 4.0.0`
- **Private Google Access** must be
  [enabled](https://cloud.google.com/vpc/docs/configure-private-google-access)
  on the input `subnetwork`.
- [*Shared VPC*](https://cloud.google.com/vpc/docs/shared-vpc) must be enabled
  when `subnetwork_project` != `project_id`.

## Usage

Modify [example.tfvars](./example.tfvars) with required and desired values.

Then perform the following commands on the root directory:

- `terraform init` to get the plugins
- `terraform plan -var-file=example.tfvars` to see the infrastructure plan
- `terraform apply -var-file=example.tfvars` to apply the infrastructure build
- `terraform destroy -var-file=example.tfvars` to destroy the built infrastructure
