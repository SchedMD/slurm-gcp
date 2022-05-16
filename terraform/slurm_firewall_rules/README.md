# Module: Slurm Firewall Rules

[FAQ](../../docs/faq.md) | [Troubleshooting](../../docs/troubleshooting.md) |
[Glossary](../../docs/glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Module: Slurm Firewall Rules](#module-slurm-firewall-rules)
  - [Overview](#overview)
  - [Usage](#usage)
  - [Dependencies](#dependencies)
    - [TerraformUser](#terraformuser)
      - [Required](#required)
  - [Module API](#module-api)

<!-- mdformat-toc end -->

## Overview

This module creates [firewall rules](../../docs/glossary.md#firewall-rules) to
support [Slurm](../../docs/glossary.md#slurm) cluster communication.

## Usage

See [examples](./examples/) directory for sample usages.

See below for a simple inclusion within your own terraform project.

```hcl
module "slurm_firewall_rules" {
  source = "git@github.com:SchedMD/slurm-gcp.git//terraform/slurm_firewall_rules?ref=v5.0.0"

  project_id         = "<PROJECT_ID>"
  network_name       = "default"
  slurm_cluster_name = "<SLURM_CLUSTER_NAME>"
}
```

> **NOTE:** Because this module is not hosted on
> [Terraform Registry](../../docs/glossary.md#terraform-registry), the version
> must be strictly controlled via
> [revision](https://www.terraform.io/language/modules/sources#selecting-a-revision)
> syntax on the source line.

## Dependencies

- [Terraform](https://www.terraform.io/downloads.html) is installed.
- [Compute Engine API](../../docs/glossary.md#compute-engine) is enabled.

### TerraformUser

#### Required

- Compute Security Admin (`roles/compute.securityAdmin`)
- Service Account Admin (`roles/iam.serviceAccountAdmin`)

## Module API

For the terraform module API reference, please see
[README_TF.md](./README_TF.md).
