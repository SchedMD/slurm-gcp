# Example: Simple Slurm Destroy Nodes

This example creates a simple slurm destroy nodes resource runner. It will run a
script on `terraform destroy` that destroys instances with the matching label of
`slurm_cluster_id` with the input value. `slurm_cluster_id` is usually a UUIDv4.

## Usage

Modify [example.tfvars](./example.tfvars) with required and desired values.

Then perform the following commands on the root directory:

- `terraform init` to get the plugins
- `terraform plan -var-file=example.tfvars` to see the infrastructure plan
- `terraform apply -var-file=example.tfvars` to apply the infrastructure build
- `terraform destroy -var-file=example.tfvars` to destroy the built infrastructure
