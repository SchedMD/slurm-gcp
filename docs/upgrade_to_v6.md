# Upgrade to v6 (from v5)

[FAQ](./faq.md) | [Glossary](./glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Upgrade to v6 (from v5)](#upgrade-to-v6-from-v5)
  - [Overview](#overview)
  - [Terraform](#terraform)
    - [Added Modules](#added-modules)
    - [Changed Modules](#changed-modules)
    - [Removed Modules](#removed-modules)
  - [Upgrade Instructions](#upgrade-instructions)

<!-- mdformat-toc end -->

## Overview

With any major release of `slurm-gcp`, there has been architectural changes to
terraform modules which impact backwards compatibility.

Please review [CHANGELOG](../CHANGELOG.md) for documented changes.

## Terraform

### Added Modules

- [\_instance_template](../terraform/slurm_cluster/modules/_instance_template/README_TF.md)
- [slurm_files](../terraform/slurm_cluster/modules/slurm_files/README_TF.md)
- [slurm_nodeset](../terraform/slurm_cluster/modules/slurm_nodeset/README_TF.md)
- [slurm_nodeset_dyn](../terraform/slurm_cluster/modules/slurm_nodeset_dyn/README_TF.md)
- [slurm_nodeset_tpu](../terraform/slurm_cluster/modules/slurm_nodeset_tpu/README_TF.md)

### Changed Modules

- [slurm_partition](../terraform/slurm_cluster/modules/slurm_partition/README_TF.md)

### Removed Modules

- `_slurm_metadata_devel`
- `_slurm_destroy_subscriptions`
- `_slurm_notify_cluster`

## Upgrade Instructions

Upgrading will be destructive and any running workload will be terminated and
lost.

The following steps assume the
[slurm_cluster](../terraform/slurm_cluster/README_TF.md) module is managing the
cluster deployment.

1. Fully drain the v5 cluster.
1. `terraform destroy` the v5 cluster.
1. Upgrade source from v5 to v6.
1. Build new images for v6 cluster.
1. Update v6 tfvars based on v5 tfvars.
1. `terraform apply` the v6 cluster.
