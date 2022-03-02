# Module: Slurm Cluster

This module creates a Slurm cluster. There are two modes of operation: cloud;
and hybrid. Cloud mode will create a VM controller. Hybrid mode will generate
`cloud.conf` and `gres.conf` files to be included in the on-prem configuration
files.

## Additional Dependencies

- [**python**](https://www.python.org/) must be installed and in `$PATH` of the
  user running `terraform apply`.
  - Required Version: `~3.6, >= 3.6.0, < 4.0.0`
- **Private Google Access** must be
  [enabled](https://cloud.google.com/vpc/docs/configure-private-google-access)
  on the input `subnetwork`.
- [*Shared VPC*](https://cloud.google.com/vpc/docs/shared-vpc) must be enabled
  when `subnetwork_project` != `project_id`.
  - Required Version: `~3.6, >= 3.6.0, < 4.0.0`
- [**Secret Manager**](https://console.cloud.google.com/security/secret-manager)
  is enabled.
