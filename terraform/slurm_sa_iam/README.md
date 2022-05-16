# Module: Slurm SA and IAM

[FAQ](../../docs/faq.md) | [Troubleshooting](../../docs/troubleshooting.md) |
[Glossary](../../docs/glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Module: Slurm SA and IAM](#module-slurm-sa-and-iam)
  - [Overview](#overview)
  - [Usage](#usage)
  - [Dependencies](#dependencies)
    - [TerraformUser](#terraformuser)
      - [Required](#required)
  - [Module API](#module-api)

<!-- mdformat-toc end -->

## Overview

This module can create three different sets of
[service accounts](../../docs/glossary.md#service-account),
[IAM Roles](../../docs/glossary.md#iam-roles), and
[access scopes](../../docs/glossary.md#access-scopes): controller; login;
compute. These [service account](../../docs/glossary.md#service-account) sets
are intended to be passed to other sections of the Slurm cluster configuration
to define [instances templates](../../docs/glossary.md#instance-template).

## Usage

See [examples](../../examples/slurm_sa_iam) directory for sample usages.

See below for a simple inclusion within your own terraform project.

```hcl
module "slurm_sa_iam" {
  source = "git@github.com:SchedMD/slurm-gcp.git//terraform/slurm_sa_iam?ref=v5.0.0"

  project_id = "<PROJECT_ID>"

  slurm_cluster_name = "<SLURM_CLUSTER_NAME>"

  account_type = "controller"
}
```

> **NOTE:** Because this module is not hosted on
> [Terraform Registry](../../docs/glossary.md#terraform-registry), the version
> must be strictly controlled via
> [revision](https://www.terraform.io/language/modules/sources#selecting-a-revision)
> syntax on the source line.

## Dependencies

- [Terraform](https://www.terraform.io/downloads.html) is installed.
- [IAM API](../../docs/glossary.md#iam) is enabled.

### TerraformUser

#### Required

- Project IAM Admin (`roles/resourcemanager.projectIamAdmin`)

## Module API

For the terraform module API reference, please see
[README_TF.md](./README_TF.md).
