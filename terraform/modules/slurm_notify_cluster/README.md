# Module: Slurm Notify Cluster

This module creates `null_resource` to manage the task of publishing a pubsub
message to a cluster topic.

## Usage

See the [simple](../../examples/slurm_notify_cluster/simple) example for a usage
example.

## Additional Dependencies

- [**python**](https://www.python.org/) must be installed and in `$PATH` of the
  user running `terraform apply`.
  - Required Version: `~3.6, >= 3.6.0, < 4.0.0`
- Python Pip Packages:
  - `addict`
