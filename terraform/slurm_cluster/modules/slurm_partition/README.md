# Module: Slurm Partition

[FAQ](../../../../docs/faq.md) |
[Troubleshooting](../../../../docs/troubleshooting.md) |
[Glossary](../../../../docs/glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Module: Slurm Partition](#module-slurm-partition)
  - [Overview](#overview)
  - [Usage](#usage)
    - [Service Account](#service-account)
  - [Dependencies](#dependencies)
  - [Module API](#module-api)

<!-- mdformat-toc end -->

## Overview

This is a submodule of [slurm_cluster](../../../slurm_cluster/README.md). It
creates a Slurm partition for
[slurm_controller_instance](../slurm_controller_instance/) or
[slurm_controller_hybrid](../slurm_controller_hybrid/).

Conceptutally, a Slurm partition is a queue that is associated with compute
resources, limits, and access controls. Users submit jobs to one or more
partitions to have their jobs be completed against requested resources within
their alloted limits and access.

This module defines a partition and its resources -- most notably, compute
nodes. Sets of compute nodes reside within a partition. Each set of compute
nodes must resolve to an
[instance template](../../../../docs/glossary.md#instance-template). Either the
[instance template](../../../../docs/glossary.md#instance-template) is: created
by definition -- module creates an
[instance template](../../../../docs/glossary.md#instance-template) using subset
of input paramters; or by the
[self link](../../../../docs/glossary.md#self-link) of an
[instance template](../../../../docs/glossary.md#instance-template) that is
managed outside of this module. Additionally, there are compute node parameters
that will override certain properties of the
[instance template](../../../../docs/glossary.md#instance-template) when
instanceated as a [VM](../../../../docs/glossary.md#vm).

Compute instances created by
[slurm_controller_instance](../slurm_controller_instance/README.md), using this
partition, run [slurmd](../../../../docs/glossary.md#slurmd) and
[slurmstepd](../../../../docs/glossary.md#slurmstepd).

## Usage

See [examples](../../examples/slurm_partition/) directory for sample usages.

See below for a simple inclusion within your own terraform project.

```hcl
module "slurm_partition" {
  source = "git@github.com:SchedMD/slurm-gcp.git//terraform/slurm_cluster/modules/slurm_partition?ref=v5.0.0"

  project_id = "<PROJECT_ID>"

  slurm_cluster_name = "<SLURM_CLUSTER_NAME>"

  partition_name = "debug"
  partition_nodes = {
    count_static  = 0
    count_dynamic = 10
    group_name    = "test"
    node_conf     = {}

    # Template by Definition
    additional_disks       = []
    can_ip_forward         = false
    disable_smt            = false
    disk_auto_delete       = true
    disk_labels            = {}
    disk_size_gb           = null
    disk_type              = null
    enable_confidential_vm = false
    enable_oslogin         = true
    enable_shielded_vm     = false
    gpu                    = null
    labels                 = {}
    machine_type           = "n1-standard-1"
    metadata               = {}
    min_cpu_platform       = null
    on_host_maintenance    = null
    preemptible            = false
    service_account = {
      email  = "<COMPUTE_SA_EMAIL>"
      scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    }
    shielded_instance_config = null
    source_image_family      = null
    source_image_project     = null
    source_image             = null
    tags                     = []

    # Template by Source
    instance_template = null
  }
  region     = "us-central1"
  subnetwork = "default"
}
```

> **NOTE:** Because this module is not hosted on
> [Terraform Registry](../../../../docs/glossary.md#terraform-registry), the
> version must be strictly controlled via
> [revision](https://www.terraform.io/language/modules/sources#selecting-a-revision)
> syntax on the source line.

### Service Account

It is recommended to generate a `compute` type
[service account](../../../../docs/glossary.md#service-account) via
[slurm_sa_iam](../../../slurm_sa_iam/README.md).

Otherwise reference
[compute service account and IAM](../../../slurm_sa_iam/README.md#compute) to
create a self managed compute
[service account](../../../../docs/glossary.md#service-account) and
[IAM](../../../../docs/glossary.md#iam).

## Dependencies

- [Terraform](https://www.terraform.io/downloads.html) is installed.
- [Compute Engine API](../../../../docs/glossary.md#compute-engine) is enabled.
- [Python](../../../../docs/glossary.md#python) is installed.
  - Required Version: `>= 3.6.0, < 4.0.0`
- [Pip](../../../../docs/glossary.md#pip) packages are installed.
  - `pip3 install -r ../../../scripts/requirements.txt --user`

## Module API

For the terraform module API reference, please see
[README_TF.md](./README_TF.md).
