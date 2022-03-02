# Module: Slurm Destroy Resource Policies

This module creates `null_resource` to manage the task of destroying cluster
compute nodes with the corresponding `slurm_cluster_id` labels.

## Usage

See the [simple](../../examples/slurm_destroy_resource_policies/simple) example for a usage
example.

## Additional Dependencies

- [**python**](https://www.python.org/) must be installed and in `$PATH` of the
  user running `terraform apply`.
  - Required Version: `~3.6, >= 3.6.0, < 4.0.0`
- Python Pip Packages:
  - `addict`
