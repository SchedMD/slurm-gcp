# Example: Simple Slurm SA IAM

[FAQ](../../../../docs/faq.md) | [Glossary](../../../../docs/glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Example: Simple Slurm SA IAM](#example-simple-slurm-sa-iam)
  - [Overview](#overview)
  - [Usage](#usage)
  - [Dependencies](#dependencies)
  - [Example API](#example-api)

<!-- mdformat-toc end -->

## Overview

This example creates a [slurm_sa_iam](../../../slurm_sa_iam/README.md).

## Usage

Modify [example.tfvars](./example.tfvars) with required and desired values.

Then perform the following commands on the root directory:

- `terraform init` to get the plugins
- `terraform plan -var-file=example.tfvars` to see the infrastructure plan
- `terraform apply -var-file=example.tfvars` to apply the infrastructure build
- `terraform destroy -var-file=example.tfvars` to destroy the built
  infrastructure

## Dependencies

- [Compute Engine API](../../../../docs/glossary.md#compute-engine) is enabled.

## Example API

For the terraform example API reference, please see
[README_TF.md](./README_TF.md).
