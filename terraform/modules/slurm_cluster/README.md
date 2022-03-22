# Module: Slurm Cluster

[FAQ](../../../docs/faq.md) | [Glossary](../../../docs/glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Module: Slurm Cluster](#module-slurm-cluster)
  - [Overview](#overview)
  - [Usage](#usage)
  - [Dependencies](#dependencies)
  - [Module API](#module-api)

<!-- mdformat-toc end -->

## Overview

This module creates a [Slurm](../../../docs/glossary.md#slurm) cluster on
[GCP](../../../docs/glossary.md#gcp). There are two modes of operation: cloud;
and hybrid. Cloud mode will create a VM controller. Hybrid mode will generate
`cloud.conf` and `gres.conf` files to be included in the on-prem configuration
files, while managing a `config.yaml` file for internal module use.

## Usage

See [examples](../../examples/slurm_cluster/) directory for sample usages.

See below for a simple inclusion within your own terraform project.

```hcl
module "slurm_cluster" {
  source = "git::https://github.com/SchedMD/slurm-gcp//terraform/modules/slurm_cluster?ref=v5.0.0"

  project_id = "<PROJECT_ID>"

  slurm_cluster_name = "<SLURM_CLUSTER_NAME>"
  slurm_cluster_id   = "<SLURM_CLUSTER_ID>"

  ...
}
```

> **NOTE:** Because this module is not hosted on
> [Terraform Registry](../../../docs/glossary.md#terraform-registry), the
> version must be strictly controlled via
> [revision](https://www.terraform.io/language/modules/sources#selecting-a-revision)
> syntax on the source line.

## Dependencies

- [Terraform](https://www.terraform.io/downloads.html) is installed.
- [GCP Cloud SDK](https://cloud.google.com/sdk/downloads) is installed.
- [Compute Engine](../../../docs/glossary.md#compute-engine) is enabled.
- [Secret Manager](../../../docs/glossary.md#secret-manager) is enabled.
- [Private Google Access](../../../../../docs/glossary.md#private-google-access)
  is enabled.
- [Python](../../../../docs/glossary.md#python) is installed.
  - Required Version: `>= 3.6.0, < 4.0.0`
- [Pip](../../../../../docs/glossary.md#pip) packages are installed.
  - `pip3 install -r ../../../scripts/requirements.txt --user`

## Module API

For the terraform module API reference, please see
[README_TF.md](./README_TF.md).
