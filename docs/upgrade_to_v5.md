# Upgrade to v5 (from v4)

[FAQ](./faq.md) | [Glossary](./glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Upgrade to v5 (from v4)](#upgrade-to-v5-from-v4)
  - [Overview](#overview)
    - [v4 Background](#v4-background)
    - [v5 Background](#v5-background)
  - [Upgrade Instructions](#upgrade-instructions)
    - [Legend](#legend)
    - [General](#general)
    - [Controller](#controller)
    - [Login](#login)
    - [Partitions](#partitions)

<!-- mdformat-toc end -->

## Overview

> **WARNING:** v5 is not backwards compatible with v4.

v5 marks a complete overhaul of the v4. v5 [terraform](./glossary.md#terraform)
modules they are built on top of
[cloud-foundation-toolkit terraform modules](https://cloud.google.com/docs/terraform/blueprints/terraform-blueprints),
which are written for and supported by
[Google Cloud Platform](./glossary.md#gcp). Supporting python scripts have been
updated to best handle v5 and its evolved needs.

### v4 Background

v4 had three Slurm modules which were maually used to form a Slurm cluster.

- compute
- controller
- login

Additionally, there was one optional supporting cluster module.

- network

### v5 Background

v5 has one Slurm module which creates the Slurm cluster.

- [slurm_cluster](../terraform/slurm_cluster/README.md)

Within the [slurm_cluster](../terraform/slurm_cluster/README.md) module exists
the main components of a Slurm cluster (as well as supporting modules).

- [slurm_controller_hybrid](../terraform/slurm_cluster/modules/slurm_controller_hybrid/README.md)
- [slurm_controller_instance](../terraform/slurm_cluster/modules/slurm_controller_instance/README.md)
- [slurm_instance_template](../terraform/slurm_cluster/modules/slurm_instance_template/README.md)
- [slurm_login_instance](../terraform/slurm_cluster/modules/slurm_login_instance/README.md)
- [slurm_partition](../terraform/slurm_cluster/modules/slurm_partition/README.md)

Additionally, there are three optional supporting cluster modules.

- [\_network](../terraform/_network/README.md)
- [slurm_firewall_rules](../terraform/slurm_firewall_rules/README.md)
- [slurm_sa_iam](../terraform/slurm_sa_iam/README.md)

## Upgrade Instructions

Module fields have change. Please follow this module field mapping guide to help
you migrate to v5 from v4.

> **NOTE:** Example terraform project fields may have different names than the
> underlying modules being called.

### Legend

| Mapping | Meaning                                                        |
| :-----: | -------------------------------------------------------------- |
|  EXACT  | Different variable name, the same value.                       |
| INVERSE | Different variable name, and inverse value.                    |
| SIMILAR | Closest approximate variable; data structure may have changed. |
|  NONE   | Cannot map variable.                                           |

### General

| v4                      | v5                                | Mapping |
| ----------------------- | --------------------------------- | :-----: |
| project                 | project_id                        |  EXACT  |
| cluster_name            | slurm_cluster_name                |  EXACT  |
| scopes                  | service_account.scopes            | SIMILAR |
| service_account         | service_account.email             | SIMILAR |
| boot_disk_size          | disk_size_gb                      |  EXACT  |
| secondary_disk          | additional_disks\[\]              | SIMILAR |
| secondary_disk_size     | additional_disks\[\].disk_size_gb | SIMILAR |
| secondary_disk_type     | additional_disks\[\].disk_type    | SIMILAR |
| image_hyperthreads      | disable_smt                       | INVERSE |
| image                   | source_image                      |  EXACT  |
| shared_vpc_host_project | subnetwork_project                |  EXACT  |
| subnetwork_name         | subnetwork                        |  EXACT  |
| subnet_depend           | slurm_depends_on                  |  EXACT  |

### Controller

| v4                            | v5                             | Mapping |
| ----------------------------- | ------------------------------ | :-----: |
| disable_compute_public_ips    | access_config\[\]              | SIMILAR |
| disable_controller_public_ips | access_config\[\]              | SIMILAR |
| compute_startup_script        | compute_startup_scripts\[\]    | SIMILAR |
| controller_startup_script     | controller_startup_scripts\[\] | SIMILAR |
| munge_key                     | N/A                            |  NONE   |
| jwt_key                       | N/A                            |  NONE   |

### Login

| v4                       | v5                | Mapping |
| ------------------------ | ----------------- | :-----: |
| disable_login_public_ips | access_config\[\] | SIMILAR |
| node_count               | num_instances     |  EXACT  |

### Partitions

| v4                   | v5                                 | Mapping |
| -------------------- | ---------------------------------- | :-----: |
| max_node_count       | node_count_dynamic_max             | SIMILAR |
| static_node_count    | node_count_static                  |  EXACT  |
| name                 | partition_name                     |  EXACT  |
| compute_disk_type    | additional_disks\[\].disk_type     | SIMILAR |
| compute_disk_size_gb | additional_disks\[\].disk_size_gb  | SIMILAR |
| compute_labels       | labels                             |  EXACT  |
| gpu_type             | gpu.type                           | SIMILAR |
| gpu_count            | gpu.count                          | SIMILAR |
| preemptible_bursting | partition_nodes\[\].preemptible    | SIMILAR |
| preemptible_bursting | partition_nodes\[\].enable_spot_vm | SIMILAR |
| vpc_subnet           | subnetwork                         |  EXACT  |
| exclusive            | enable_job_exclusive               |  EXACT  |
| enable_placement     | enable_placement_groups            |  EXACT  |
| regional_policy      | zone_policy_allow                  | SIMILAR |
| regional_policy      | zone_policy_deny                   | SIMILAR |
| bandwidth_tier       | N/A                                |  NONE   |
