# Cloud Cluster Guide

[FAQ](./faq.md) | [Troubleshooting](./troubleshooting.md) |
[Glossary](./glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Cloud Cluster Guide](#cloud-cluster-guide)
  - [Overview](#overview)
  - [GCP Marketplace](#gcp-marketplace)
  - [Terraform](#terraform)
    - [Quickstart Examples](#quickstart-examples)

<!-- mdformat-toc end -->

## Overview

This guide focuses on setting up a cloud [Slurm cluster](./glossary.md#slurm).
With cloud, there are decisions that need to be made and certain considerations
taken into account. This guide will cover them and their recommended solutions.

There are two deployment methods for cloud cluster management:

- [GCP Marketplace](#gcp-marketplace)
- [Terraform](#terraform)

## GCP Marketplace

This deployment method leverages
[GCP Marketplace](./glossary.md#gcp-marketplace) to make setting up clusters a
breeze without leaving your browser. While this method is simplier and less
flexible, it is great for exploring what `slurm-gcp` is!

See the [Marketplace Guide](./marketplace.md) for setup instructions and more
information.

## Terraform

This deployment method leverages [Terraform](./glossary.md#terraform) to deploy
and manage cluster infrastructure. While this method can be more complex, it is
a robust option. `slurm-gcp` provides terraform modules that enables you to
create a Slurm cluster with ease.

See the [slurm_cluster module](../terraform/slurm_cluster/README.md) for
details.

If you are unfamiliar with [terraform](./glossary.md#terraform), then please
checkout out the [documentation](https://www.terraform.io/docs) and
[starter guide](https://learn.hashicorp.com/collections/terraform/gcp-get-started)
to get you familiar.

### Quickstart Examples

See the
[full cluster example](../terraform/slurm_cluster/examples/slurm_cluster/cloud/full/README.md)
for a great example to get started with. It will create all the infrastructure,
service accounts and IAM to minimally support a Slurm cluster. The
[TerraformUser](./glossary.md#terraformuser) will require more
[roles](./glossary.md#iam-roles) to create the other supporting resources. You
can configure certain elements of the example cluster, which is useful for
testing.

See the
[basic cluster example](../terraform/slurm_cluster/examples/slurm_cluster/cloud/basic/README.md)
for a great example to base a production configuration off of. It provides the
bare minimum and leaves the rest to you. This allows for fine grain control over
the cluster environment and removes [role](./glossary.md#iam-roles) requirements
from the [TerraformUser](./glossary.md#terraformuser). You can configure certain
elements of the example cluster, which is useful for testing.

> **NOTE:** It is recommended to use the
> [slurm_cluster module](../terraform/slurm_cluster/README.md) in your own
> [terraform project](./glossary.md#terraform-project). It may be useful to copy
> and modify one of the provided examples.
