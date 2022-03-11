# Example: Winbind Slurm Cluster

[FAQ](../../../../../docs/faq.md) | [Glossary](../../../../../docs/glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Example: Winbind Slurm Cluster](#example-winbind-slurm-cluster)
  - [Overview](#overview)
  - [Usage](#usage)
  - [Dependencies](#dependencies)
  - [Module API](#module-api)

<!-- mdformat-toc end -->

## Overview

This example creates a
[slurm_cluster](../../../../modules/slurm_cluster/README.md) in cloud mode. It
uses a custom script, via `controller_d`, to provision authentication with
winbind and an Active Directory server.
[os-login](../../../../../docs/glossary.md#os-login) is disabled.

## Usage

Modify [example.tfvars](./example.tfvars) with required and desired values.

Then perform the following commands on the root directory:

- `terraform init` to get the plugins
- `terraform plan -var-file=example.tfvars` to see the infrastructure plan
- `terraform apply -var-file=example.tfvars` to apply the infrastructure build
- `terraform destroy -var-file=example.tfvars` to destroy the built
  infrastructure

## Dependencies

- [Compute Engine](../../../../../docs/glossary.md#compute-engine) is enabled.
- [Secret Manager](../../../../../docs/glossary.md#secret-manager) is enabled.
- [Private Google Access](../../../../../docs/glossary.md#private-google-access)
  is enabled.
- [Python](../../../../../docs/glossary.md#python) is installed.
  - Required Version: `>= 3.6.0, < 4.0.0`
- [Pip](../../../../../docs/glossary.md#pip) packages are installed:
  - [addict](https://pypi.org/project/addict/)

## Module API

For the terraform module API reference, please see
[README_TF.md](./README_TF.md).
