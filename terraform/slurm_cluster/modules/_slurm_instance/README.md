# Module: Slurm Instance

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Module: Slurm Instance](#module-slurm-instance)
  - [Overview](#overview)
  - [Module API](#module-api)

<!-- mdformat-toc end -->

## Overview

This module creates a [compute instance](../../../../docs/glossary.md#vm) from
[instance template](../../../../docs/glossary.md#instance-template) for a
[Slurm cluster](../slurm_cluster/README.md).

> **NOTE:** This module is only intended to be used by Slurm modules. For
> general usage, please consider using:
>
> - [terraform-google-modules/vm/google//modules/compute_instance](https://registry.terraform.io/modules/terraform-google-modules/vm/google/latest/submodules/compute_instance).

> **WARNING:** The source image is not modified. Make sure to use a compatible
> source image.

## Module API

For the terraform module API reference, please see
[README_TF.md](./README_TF.md).
