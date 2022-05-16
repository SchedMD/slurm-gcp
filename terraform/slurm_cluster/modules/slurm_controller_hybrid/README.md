# Module: Slurm Controller Hybrid

[FAQ](../../../../docs/faq.md) |
[Troubleshooting](../../../../docs/troubleshooting.md) |
[Glossary](../../../../docs/glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Module: Slurm Controller Hybrid](#module-slurm-controller-hybrid)
  - [Overview](#overview)
  - [Usage](#usage)
  - [Module API](#module-api)

<!-- mdformat-toc end -->

## Overview

This is a submodule of [slurm_cluster](../../../slurm_cluster/README.md).. This
module creates a
[null_resource](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource)
to manage the task generating all files and cloud resources required to support
a hybrid environment in [GCP](../../../../docs/glossary.md#gcp).

## Usage

See [examples](../../examples/slurm_controller_hybrid/) directory for sample
usages.

See below for a simple inclusion within your own terraform project.

```hcl
module "slurm_controller_hybrid" {
  source = "git@github.com:SchedMD/slurm-gcp.git//terraform/modules/slurm_controller_hybrid?ref=v5.0.0"

  project_id = "<PROJECT_ID>"

  slurm_cluster_name = "<SLURM_CLUSTER_NAME>"

  output_dir = "/etc/slurm"
}
```

> **NOTE:** Because this module is not hosted on
> [Terraform Registry](../../../../docs/glossary.md#terraform-registry), the
> version must be strictly controlled via
> [revision](https://www.terraform.io/language/modules/sources#selecting-a-revision)
> syntax on the source line.

## Module API

For the terraform module API reference, please see
[README_TF.md](./README_TF.md).
