# Example: Basic Cloud Slurm Cluster

[FAQ](../../../../../docs/faq.md) | [Glossary](../../../../../docs/glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Example: Basic Cloud Slurm Cluster](#example-basic-cloud-slurm-cluster)
  - [Overview](#overview)
  - [Usage](#usage)
  - [Dependencies](#dependencies)
    - [TerraformUser](#terraformuser)
      - [Optional](#optional)
  - [Example API](#example-api)

<!-- mdformat-toc end -->

## Overview

This example creates a [slurm_cluster](../../../../modules/slurm_cluster/) in
cloud mode. It highly configurable through tfvars.

All other components required to support the slurm cluster are not created: VPC;
subnetwork; firewall rules; service accounts.

## Usage

Modify [example.tfvars](./example.tfvars) with required and desired values.

Then perform the following commands on this
[terraform project](../../../../../docs/glossary.md#terraform-project) root
directory:

- `terraform init` to get the plugins
- `terraform validate -var-file=example.tfvars` to validate the configuration
- `terraform plan -var-file=example.tfvars` to see the infrastructure plan
- `terraform apply -var-file=example.tfvars` to apply the infrastructure build
- `terraform destroy -var-file=example.tfvars` to destroy the built
  infrastructure

## Dependencies

See
[slurm_cluster dependencies](../../../../modules/slurm_cluster/README.md#dependencies)
for core dependencies.

This
[example terraform project](../../../../../docs/glossary.md#terraform-project)
has additional dependencies to satisfy.

### TerraformUser

#### Optional

- Service Usage Admin (`roles/serviceusage.serviceUsageAdmin`)

## Example API

For the terraform example API reference, please see
[README_TF.md](./README_TF.md).
