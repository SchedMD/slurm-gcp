# Module: Slurm Instance Template

[FAQ](../../../../docs/faq.md) |
[Troubleshooting](../../../../docs/troubleshooting.md) |
[Glossary](../../../../docs/glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Module: Slurm Instance Template](#module-slurm-instance-template)
  - [Overview](#overview)
  - [Usage](#usage)
    - [Service Account](#service-account)
  - [Module API](#module-api)

<!-- mdformat-toc end -->

## Overview

This is a submodule of [slurm_cluster](../../../slurm_cluster/README.md). This
module creates an
[instance template](../../../../docs/glossary.md#instance-template) intended to
be used by [slurm_controller_instance](../slurm_controller_instance/README.md),
and [slurm_login_instance](../slurm_login_instance/README.md), and
[slurm_partition](../slurm_partition/README.md).

> **NOTE:** [slurm_cluster_name](./README_TF.md#inputs) is appended to network
> [tags](./README_TF.md#inputs).

## Usage

See [examples](../../examples/slurm_instance_template/) directory for sample
usages.

See below for a simple inclusion within your own terraform project.

```hcl
module "slurm_instance_template" {
  source = "git@github.com:SchedMD/slurm-gcp.git//terraform/slurm_cluster/modules/slurm_instance_template?ref=v5.0.0"

  project_id = "<PROJECT_ID>"

  slurm_cluster_name = "<SLURM_CLUSTER_NAME>"

  network = "default"
  service_account = {
    email  = "<SA_EMAIL>"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}
```

> **NOTE:** Because this module is not hosted on
> [Terraform Registry](../../../../docs/glossary.md#terraform-registry), the
> version must be strictly controlled via
> [revision](https://www.terraform.io/language/modules/sources#selecting-a-revision)
> syntax on the source line.

### Service Account

It is recommended to generate a
[service account](../../../../docs/glossary.md#service-account) via
[slurm_sa_iam](../slurm_sa_iam/).

Otherwise reference [slurm_sa_iam](../slurm_sa_iam/README.md#service-accounts)
to create a self managed compute
[service account](../../../../docs/glossary.md#service-account) and
[IAM](../../../../docs/glossary.md#iam).

## Module API

For the terraform module API reference, please see
[README_TF.md](./README_TF.md).
