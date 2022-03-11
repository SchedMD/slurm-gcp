# Cloud Cluster Guide

[FAQ](./faq.md) | [Glossary](./glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Cloud Cluster Guide](#cloud-cluster-guide)
  - [Overview](#overview)
  - [GCP Marketplace](#gcp-marketplace)
  - [Terraform](#terraform)
    - [Requirements](#requirements)
    - [Setup](#setup)
      - [Maximal Configuration](#maximal-configuration)
      - [Minimal Configuration](#minimal-configuration)

<!-- mdformat-toc end -->

## Overview

This guide focuses on setting up a cloud [slurm cluster](./glossary.md#slurm).
With cloud, there are decisions that need to be made and certain considerations
taken into account. This guide will cover them and their recommended solutions.

There are two deployment methods for cloud cluster management:

- [GCP Marketplace](#gcp-marketplace)
- [Terraform](#terraform)

## GCP Marketplace

This deployment method leverages
[GCP Marketplace](./glossary.md#gcp-marketplace) to make setting up clusters a
breeze without leaving your browser. While this method is simplier, it can be
less flexable but it is a great starting place to explore what `slurm-gcp` is!

See the [Marketplace Guide](./marketplace.md) for setup instructions and more
information.

## Terraform

This deployment method leverages [Terraform](./glossary.md#terraform) to make
cluster management composable, accountable, and consistant. While this method
can be more complex, it is a robust option.

See the [slurm_cluster module](../terraform/modules/slurm_cluster/README.md) for
details.

See the [full example](../terraform/examples/slurm_cluster/cloud/full/README.md)
for an all inclusive example. This example requires the most
[roles](./glossary.md#iam-roles) but creates everything you need for a running
slurm cluster. Depending on organizational constraints, this may be a great
example as a starting point and for testing.

See the
[basic example](../terraform/examples/slurm_cluster/cloud/basic/README.md) for a
minimal but configurable cluster example. This example requires the least
[roles](./glossary.md#iam-roles) but does not create everything required for
running a slurm cluster. Depending on organizational constraints, this may be a
great example for production.

### Requirements

Please review the dependencies and requirements of the following items:

- [slurm cluster](../terraform/modules/slurm_cluster/README.md)
- [slurm_sa_iam](../terraform/modules/slurm_sa_iam/README.md)
- [slurm_firewall_rules](../terraform/modules/slurm_firewall_rules/README.md)
- VPC Network
  - Subnetwork

### Setup

#### Maximal Configuration

1. Install software requirements.
1. Deploy
   [full example](../terraform/examples/slurm_cluster/cloud/full/README.md).

#### Minimal Configuration

1. Install software requirements.
1. Deploy
   [basic example](../terraform/examples/slurm_cluster/cloud/basic/README.md).
