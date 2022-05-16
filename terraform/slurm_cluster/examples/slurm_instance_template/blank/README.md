# Example: Slurm Blank Template

[FAQ](../../../../../docs/faq.md) | [Glossary](../../../../../docs/glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Example: Slurm Blank Template](#example-slurm-blank-template)
  - [Overview](#overview)
  - [Usage](#usage)
  - [Dependencies](#dependencies)
  - [Example API](#example-api)

<!-- mdformat-toc end -->

## Overview

This exmaple creates a
[slurm_instance_template](../../../modules/slurm_instance_template/README.md).
It is compatible with:

- [slurm_controller_instance](../../../modules/slurm_controller_instance/README.md)
- [slurm_login_instance](../../../modules/slurm_login_instance/README.md)
- [slurm_partition](../../../modules/slurm_partition/README.md)

## Usage

Modify [example.tfvars](./example.tfvars) with required and desired values.

Then perform the following commands on the root directory:

- `terraform init` to get the plugins
- `terraform plan -var-file=example.tfvars` to see the infrastructure plan
- `terraform apply -var-file=example.tfvars` to apply the infrastructure build
- `terraform destroy -var-file=example.tfvars` to destroy the built
  infrastructure

## Dependencies

- [Compute Engine API](../../../../../docs/glossary.md#compute-engine) is
  enabled.

## Example API

For the terraform example API reference, please see
[README_TF.md](./README_TF.md).
