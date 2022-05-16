# Example: Simple Hybrid Slurm Cluster

[FAQ](../../../../../../docs/faq.md) |
[Glossary](../../../../../../docs/glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Example: Simple Hybrid Slurm Cluster](#example-simple-hybrid-slurm-cluster)
  - [Overview](#overview)
  - [Usage](#usage)
  - [Dependencies](#dependencies)
  - [Module API](#module-api)

<!-- mdformat-toc end -->

## Overview

This example creates a [slurm_cluster](../../../../../slurm_cluster/README.md)
in hybrid mode.

## Usage

Modify [example.tfvars](./example.tfvars) with required and desired values.

Then perform the following commands on this
[terraform project](../../../../../../docs/glossary.md#terraform-project) root
directory:

- `terraform init` to get the plugins
- `terraform validate` to validate the configuration
- `terraform plan -var-file=example.tfvars` to see the infrastructure plan
- `terraform apply -var-file=example.tfvars` to apply the infrastructure build
- `terraform destroy -var-file=example.tfvars` to destroy the built
  infrastructure

## Dependencies

- [slurm_cluster module](../../../../README.md#dependencies)

## Module API

For the terraform module API reference, please see
[README_TF.md](./README_TF.md).
