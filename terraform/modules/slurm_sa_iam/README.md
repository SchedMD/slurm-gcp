# Module: Slurm SA and IAM

[FAQ](../../../docs/faq.md) | [Glossary](../../../docs/glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Module: Slurm SA and IAM](#module-slurm-sa-and-iam)
  - [Overview](#overview)
    - [Service Accounts](#service-accounts)
      - [Controller](#controller)
        - [Roles](#roles)
        - [Scopes](#scopes)
      - [Compute](#compute)
        - [Roles](#roles-1)
        - [Scopes](#scopes-1)
      - [Login](#login)
        - [Roles](#roles-2)
        - [Scopes](#scopes-2)
  - [Usage](#usage)
  - [Dependencies](#dependencies)
  - [Module API](#module-api)

<!-- mdformat-toc end -->

## Overview

This module can create three different minimal sets of
[service accounts](../../../docs/glossary.md#service-account),
[IAM Roles](../../../docs/glossary.md#iam-roles), and
[access scopes](../../../docs/glossary.md#access-scopes): controller; login;
compute. These [service account](../../../docs/glossary.md#service-account) sets
are intended to be passed to other sections of the slurm cluster configuration
to define [instances templates](../../../docs/glossary.md#instance-template).

### Service Accounts

These are the [IAM Roles](../../../docs/glossary.md#iam-roles) and
[access scopes](../../../docs/glossary.md#access-scopes) for each
[service account](../../../docs/glossary.md#service-account) type produced by
this module.

Please refer to
[Understanding IAM Roles](https://cloud.google.com/iam/docs/understanding-roles)
for more information.

#### Controller

Intended to be attached to a controller
[instance template](../../../docs/glossary.md#instance-template) for
[slurm_controller_instance](../slurm_controller_instance/).

##### Roles

- `roles/bigquery.dataEditor`
- `roles/compute.instanceAdmin.v1`
- `roles/compute.instanceAdmin` (Beta)
- `roles/iam.serviceAccountUser`
- `roles/logging.logWriter`
- `roles/monitoring.metricWriter`

##### Scopes

- `https://www.googleapis.com/auth/cloud-platform`

#### Compute

Intended to be attached to compute
[instance templates](../../../docs/glossary.md#instance-template) created by
[slurm_partition](../slurm_partition/).

##### Roles

- `roles/logging.logWriter`
- `roles/monitoring.metricWriter`

##### Scopes

- `https://www.googleapis.com/auth/cloud-platform`

#### Login

Intended to be attached to login
[instance templates](../../../docs/glossary.md#instance-template) for
[slurm_login_instance](../slurm_login_instance/).

##### Roles

- `roles/logging.logWriter`
- `roles/monitoring.metricWriter`

##### Scopes

- `https://www.googleapis.com/auth/cloud-platform`

## Usage

See [examples](../../examples/slurm_sa_iam) directory for sample usages.

See below for a simple inclusion within your own terraform project.

```hcl
module "slurm_sa_iam" {
  source = "git::https://github.com/SchedMD/slurm-gcp//terraform/modules/slurm_sa_iam?ref=v5.0.0"

  project_id = "<PROJECT_ID>"

  slurm_cluster_name = "<SLURM_CLUSTER_NAME>"

  account_type = "controller"
}
```

> **NOTE:** Because this module is not hosted on
> [Terraform Registry](../../../docs/glossary.md#terraform-registry), the
> version must be strictly controlled via
> [revision](https://www.terraform.io/language/modules/sources#selecting-a-revision)
> syntax on the source line.

## Dependencies

- [Terraform](https://www.terraform.io/downloads.html) is installed.
- [Compute Engine API](../../../docs/glossary.md#compute-engine) is enabled.

## Module API

For the terraform module API reference, please see
[README_TF.md](./README_TF.md).
