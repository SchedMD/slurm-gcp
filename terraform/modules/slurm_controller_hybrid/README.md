# Module: Slurm Controller Hybrid

This module manages resources required by an on premises Slurm controller to be
able to burst workload to the cloud.

## Usage

See the [simple controller](../../examples/slurm_controller_hybrid/simple)
example or the [simple cluster](../../examples/slurm_cluster/simple_hybrid)
example for usage examples.

## Additional Dependencies

- [**python**](https://www.python.org/) must be installed and in `$PATH` of the
  user running `terraform apply`.
  - Required Version: `~3.6, >= 3.6.0, < 4.0.0`
- [**Secret Manager**](https://console.cloud.google.com/security/secret-manager)
  is enabled.
