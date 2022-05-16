# Module: Network

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Module: Network](#module-network)
  - [Overview](#overview)
  - [Dependencies](#dependencies)
    - [TerraformUser](#terraformuser)
      - [Required](#required)
  - [Module API](#module-api)

<!-- mdformat-toc end -->

## Overview

This module creates a network and a nat and router for each specified
subnetwork.

> **NOTE:** This module is intended for example purposes. For general usage,
> please consider using:
>
> - [terraform-google-modules/network/google](https://registry.terraform.io/modules/terraform-google-modules/network/google/latest)
> - [terraform-google-modules/cloud-router/google](https://registry.terraform.io/modules/terraform-google-modules/cloud-router/google/latest)
> - [terraform-google-modules/cloud-nat/google](https://registry.terraform.io/modules/terraform-google-modules/cloud-nat/google/latest)

## Dependencies

- [Terraform](https://www.terraform.io/downloads.html) is installed.
- [Compute Engine API](../../docs/glossary.md#compute-engine) is enabled.

### TerraformUser

#### Required

- Compute Network Admin (`roles/compute.networkAdmin`)

## Module API

For the terraform module API reference, please see
[README_TF.md](./README_TF.md).
