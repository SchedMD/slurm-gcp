# TPU setup guide

[FAQ](./faq.md) | [Troubleshooting](./troubleshooting.md) |
[Glossary](./glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [TPU setup guide](#tpu-setup-guide)
  - [Overview](#overview)
  - [Terraform](#terraform)
    - [Quickstart Examples](#quickstart-examples)

<!-- mdformat-toc end -->

## Overview

This guide focuses on setting up a tpu nodeset for a slurm cloud cluster. But
first it is important to take into account the following considerations.

- A partition cannot contain simultaneously a normal nodeset and a tpu nodeset.
- TPU nodes are expected to only run one job simultaneously, this is due to the
  fact that TPU devices cannot be constrained individually for every job.
- TPU nodes take more time to spin up than regular nodes, this is reflected in
  the partition ResumeTimeout and SuspendTimeout that contains TPU nodes
- slurm is executed in TPU nodes using a docker container
- TPU nodes in slurm will have different name that the one seen in GCP, that is
  because TPU names cannot be choosen or known before starting them up

TPUs are configured in slurm with what is called a nodeset_tpu, this is like a
regular nodeset but for TPU nodes, and it takes into account the differences
between both nodesets. This is configured in terraform modules slurm_cluster and
slurm_nodeset_tpu.

## Terraform

Terraform is used for creating the configuration for slurm to spin up TPU nodes.

See the [slurm_cluster module](../terraform/slurm_cluster/README.md) and the
[slurm_nodeset_tpu module](../terraform/slurm_cluster/modules/slurm_nodeset_tpu/README.md)
for details.

If you are unfamiliar with [terraform](./glossary.md#terraform), then please
checkout out the [documentation](https://www.terraform.io/docs) and
[starter guide](https://learn.hashicorp.com/collections/terraform/gcp-get-started)
to get you familiar.

### Quickstart Examples

See the
[simple_cloud_tpu](../terraform/slurm_cluster/examples/slurm_cluster/simple_cloud_tpu/README.md)
example for an extensible and robust example. It can be configured to handle
creation of all supporting resources (e.g. network, service accounts) or leave
that to you. Slurm can be configured with partitions and nodesets as desired.

> **NOTE:** It is recommended to use the
> [slurm_cluster module](../terraform/slurm_cluster/README.md) in your own
> [terraform project](./glossary.md#terraform-project). It may be useful to copy
> and modify one of the provided examples.

Alternatively, see
[HPC Blueprints](https://cloud.google.com/hpc-toolkit/docs/setup/hpc-blueprint)
for
[HPC Toolkit](https://cloud.google.com/blog/products/compute/new-google-cloud-hpc-toolkit)
examples.

<!-- Links -->
