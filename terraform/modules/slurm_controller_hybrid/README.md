# Module: Slurm Controller Hybrid

[FAQ](../../../docs/faq.md) | [Glossary](../../../docs/glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Module: Slurm Controller Hybrid](#module-slurm-controller-hybrid)
  - [Overview](#overview)
  - [Usage](#usage)
  - [Dependencies](#dependencies)
  - [Module API](#module-api)

<!-- mdformat-toc end -->

## Overview

This is a submodule of [slurm_cluster](../slurm_cluster/). This module creates a
[null_resource](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource)
to manage the task generating all files and cloud resources required to support
a hybrid environment in [GCP](../../../docs/glossary.md#gcp).

## Usage

See [examples](../../examples/slurm_controller_hybrid/) directory for sample
usages.

See below for a simple inclusion within your own terraform project.

```hcl
module "slurm_controller_hybrid" {
  source = "git::https://github.com/SchedMD/slurm-gcp//terraform/modules/slurm_controller_hybrid?ref=v5.0.0"

  project_id = "<PROJECT_ID>"

  slurm_cluster_name = "<SLURM_CLUSTER_NAME>"
  slurm_cluster_id   = "<SLURM_CLUSTER_ID>"

  munge_key  = "<MUNGE_KEY>"
  output_dir = "/etc/slurm/gcp"
}
```

> **NOTE:** Because this module is not hosted on
> [Terraform Registry](../../../docs/glossary.md#terraform-registry), the
> version must be strictly controlled via
> [revision](https://www.terraform.io/language/modules/sources#selecting-a-revision)
> syntax on the source line.

## Dependencies

Please review the dependencies and requirements of the following items:

- [Terraform](https://www.terraform.io/downloads.html) is installed.
- [GCP Cloud SDK](https://cloud.google.com/sdk/downloads) is installed.
- [Compute Engine](../../../docs/glossary.md#compute-engine) is enabled.
- [Secret Manager](../../../docs/glossary.md#secret-manager) is enabled.
- [Python](../../../docs/glossary.md#python) is installed.
  - Required Version: `>= 3.6.0, < 4.0.0`
- [Pip](../../../../../docs/glossary.md#pip) packages are installed.
  - `pip3 install -r ../../../scripts/requirements.txt --user`

## Module API

For the terraform module API reference, please see
[README_TF.md](./README_TF.md).
