# Module: Slurm Destroy Subscriptions

[FAQ](../../../../docs/faq.md) |
[Troubleshooting](../../../../docs/troubleshooting.md) |
[Glossary](../../../../docs/glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Module: Slurm Destroy Subscriptions](#module-slurm-destroy-subscriptions)
  - [Overview](#overview)
  - [Usage](#usage)
  - [Dependencies](#dependencies)
  - [Module API](#module-api)

<!-- mdformat-toc end -->

## Overview

This module creates a
[null_resource](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource)
to manage the task of destroying Pub/Sub subscriptions that are labeled with the
input [slurm_cluster_name](./README_TF.md#inputs). It can be configured with
triggers that will cause it to re-run the task when infrastructure changes.

## Usage

See [examples](../../examples/slurm_destroy_subscriptions/) directory for sample
usages.

See below for a simple inclusion within your own terraform project.

```hcl
module "slurm_destroy_subscriptions" {
  source = "git@github.com:SchedMD/slurm-gcp.git//terraform/slurm_cluster/modules/slurm_destroy_subscriptions?ref=v5.0.0"

  slurm_cluster_name = "<SLURM_CLUSTER_NAME>"
}
```

> **NOTE:** Because this module is not hosted on
> [Terraform Registry](../../../../docs/glossary.md#terraform-registry), the
> version must be strictly controlled via
> [revision](https://www.terraform.io/language/modules/sources#selecting-a-revision)
> syntax on the source line.

## Dependencies

- [GCP Cloud SDK](https://cloud.google.com/sdk/downloads) is installed.
- [Python](../../../../docs/glossary.md#python) is installed.
  - Required Version: `>= 3.6.0, < 4.0.0`
- [Pip](../../../../docs/glossary.md#pip) packages are installed.
  - `pip3 install -r ../../../scripts/requirements.txt --user`

## Module API

For the terraform module API reference, please see
[README_TF.md](./README_TF.md).
