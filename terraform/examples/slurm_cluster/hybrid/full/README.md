# Example: Full Hybrid Slurm Cluster

[FAQ](../../../../../docs/faq.md) | [Glossary](../../../../../docs/glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Example: Full Hybrid Slurm Cluster](#example-full-hybrid-slurm-cluster)
  - [Overview](#overview)
  - [Dependencies](#dependencies)
  - [Usage](#usage)

<!-- mdformat-toc end -->

## Overview

This example creates a [slurm_cluster](../../../../modules/slurm_cluster/README.md) in hybrid mode.
All other components required to support a slurm cluster are minimally created as well: VPC; subnetwork; firewall rules; service accounts.
It highly configurable through tfvars.

## Dependencies

- [Compute Engine](../../../../../docs/glossary.md#compute-engine) is enabled.
- [Secret Manager](../../../../../docs/glossary.md#secret-manager) is enabled.
- [Python](../../../../../docs/glossary.md#python) is installed.
  - Required Version: `>= 3.6.0, < 4.0.0`
- [Pip](../../../../../docs/glossary.md#pip) packages are installed:
  - [addict](https://pypi.org/project/addict/)

## Usage

Modify [example.tfvars](./example.tfvars) with required and desired values.

Then perform the following commands on the root directory:

- `terraform init` to get the plugins
- `terraform plan -var-file=example.tfvars` to see the infrastructure plan
- `terraform apply -var-file=example.tfvars` to apply the infrastructure build
- `terraform destroy -var-file=example.tfvars` to destroy the built infrastructure
