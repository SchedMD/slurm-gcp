# Example: Simple Slurm Controller Instance

[FAQ](../../../../../docs/faq.md) | [Glossary](../../../../../docs/glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Example: Simple Slurm Controller Instance](#example-simple-slurm-controller-instance)
  - [Overview](#overview)
  - [Usage](#usage)
  - [Dependencies](#dependencies)
  - [Example API](#example-api)

<!-- mdformat-toc end -->

## Overview

This example creates a
[slurm_controller_instance](../../../modules/slurm_controller_instance/README.md)
from
[slurm_instance_template](../../../modules/slurm_instance_template/README.md).

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
- [Secret Manager API](../../../../../docs/glossary.md#secret-manager) is
  enabled.
- [Private Google Access](../../../../../docs/glossary.md#private-google-access)
  is enabled.
- [Python](../../../../../docs/glossary.md#python) is installed.
  - Required Version: `>= 3.6.0, < 4.0.0`
- [Pip](../../../../../docs/glossary.md#pip) packages are installed.
  - `pip3 install -r ../../../../scripts/requirements.txt --user`

## Example API

For the terraform example API reference, please see
[README_TF.md](./README_TF.md).
