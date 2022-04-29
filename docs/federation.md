# Federated Cluster Guide

[FAQ](./faq.md) | [Troubleshooting](./troubleshooting.md) |
[Glossary](./glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Federated Cluster Guide](#federated-cluster-guide)
  - [Overview](#overview)
    - [Federation](#federation)
    - [Multi-Cluster](#multi-cluster)
    - [General Requirements](#general-requirements)
  - [Shared Slurmdbd](#shared-slurmdbd)
    - [Additional Requirements](#additional-requirements)
  - [Multiple Slurmdbd](#multiple-slurmdbd)
    - [Additional Requirements](#additional-requirements-1)

<!-- mdformat-toc end -->

## Overview

This guide focuses on setting up a
[federation of Slurm clusters](./glossary.md#federated-cluster) and
[Slurm multi-cluster](./glossary.md#multi-cluster).

[Federation](#federation) is a superset of [multi-cluster](#multi-cluster). By
setting up federation, you are also setting up multi-cluster.

If using [slurm_cluster terraform module](../terraform/slurm_cluster/README.md),
please refer to [multiple-slurmdbd](#multiple-slurmdbd) section.

> **NOTE:** [slurmdbd](./glossary.md#slurmdbd) and the database (e.g. mariadb,
> mysql, etc..).

### Federation

> Slurm includes support for creating a federation of clusters and scheduling
> jobs in a peer-to-peer fashion between them. Jobs submitted to a federation
> receive a unique job ID that is unique among all clusters in the federation. A
> job is submitted to the local cluster (the cluster defined in the slurm.conf)
> and is then replicated across the clusters in the federation. Each cluster
> then independently attempts to the schedule the job based off of its own
> scheduling policies. The clusters coordinate with the "origin" cluster
> (cluster the job was submitted to) to schedule the job.

> Each cluster in the federation independently attempts to schedule each job
> with the exception of coordinating with the origin cluster (cluster where the
> job was submitted to) to allocate resources to a federated job. When a cluster
> determines it can attempt to allocate resources for a job it communicates with
> the origin cluster to verify that no other cluster is attempting to allocate
> resources at the same time.

### Multi-Cluster

> Slurm offers the ability to target commands to other clusters instead of, or
> in addition to, the local cluster on which the command is invoked. When this
> behavior is enabled, users can submit jobs to one or many clusters and receive
> status from those remote clusters.

> When sbatch, salloc or srun is invoked with a cluster list, Slurm will
> immediately submit the job to the cluster that offers the earliest start time
> subject its queue of pending and running jobs. Slurm will make no subsequent
> effort to migrate the job to a different cluster (from the list) whose
> resources become available when running jobs finish before their scheduled end
> times.

### General Requirements

- Use Slurmdbd
- All clusters must be able to communicate with each
  [slurmdbd](./glossary.md#slurmdbd) and [slurmctld](./glossary.md#slurmctld).
- [slurmdbd](./glossary.md#slurmdbd) to database forms a one-to-one
  relationship.
- Each cluster must be able to communicate with
  [slurmdbd](./glossary.md#slurmdbd).
  - Either all clusters and slurmdbd uses the same [MUNGE](./glossary.md#munge)
    key.
  - Or, all clusters have a different [MUNGE](./glossary.md#munge) key and an
    [alternative authentication](https://slurm.schedmd.com/slurmdbd.conf.html#OPT_AuthAltParameters)
    method for [slurmdbd](./glossary.md#slurmdbd).
- (Optional) Login nodes must be able to directly communicate with compute nodes
  (otherwise srun and salloc will fail).

## Shared Slurmdbd

1. Deploy [slurmdbd](./glossary.md#slurmdbd) and database (e.g. mariadb, mysql,
   etc..).

1. Deploy Slurm clusters by any chosen methods (e.g. cloud, hybrid, etc..).

   > **WARNING:** This type of configuration is not supported by
   > [slurm_cluster terraform module](../terraform/slurm_cluster/README.md); see
   > the [multiple-slurmdbd](#multiple-slurmdbd) section instead.

1. Update *slurm.conf* with accounting storage options:

   - [AccountingStorageHost](https://slurm.schedmd.com/slurm.conf.html#OPT_AccountingStorageHost)
   - [AccountingStoragePort](https://slurm.schedmd.com/slurm.conf.html#OPT_AccountingStoragePort)
   - [AccountingStorageUser](https://slurm.schedmd.com/slurm.conf.html#OPT_AccountingStorageUser)
   - [AccountingStoragePass](https://slurm.schedmd.com/slurm.conf.html#OPT_AccountingStoragePass)

   ```conf
   # slurm.conf
   AccountingStorageHost=<HOSTNAME/IP>
   AccountingStoragePort=<HOST_PORT>
   AccountingStorageUser=<USERNAME>
   AccountingStoragePass=<PASSWORD>
   ```

1. Add clusters into federation.

   ```sh
   sacctmgr add federation <federation_name> [clusters=<list_of_clusters>]
   ```

### Additional Requirements

- User UID and GID are consistant accross all federated clusters.

## Multiple Slurmdbd

1. Deploy [slurmdbd](./glossary.md#slurmdbd)s and databases (e.g. mariadb,
   mysql, etc..).

   > **NOTE:**
   > [slurm_cluster terraform module](../terraform/slurm_cluster/README.md)
   > conflates the controller instance and the database instance.

1. Deploy Slurm clusters by any chosen methods (e.g. cloud, hybrid, etc..).

   > **WARNING:** If using the
   > [slurm_cluster terraform module](../terraform/slurm_cluster/README.md), do
   > not use the `cloudsql` input, as this does not work with a federation
   > setup.

1. Update each *slurm.conf* with:

   - [AccountingStorageExternalHost](https://slurm.schedmd.com/slurm.conf.html#OPT_AccountingStorageExternalHost)

   ```conf
   # slurm.conf
   AccountingStorageExternalHost=<host/ip>[:port][,<host/ip>[:port]]
   ```

1. Add clusters into federation.

   ```sh
   sacctmgr add federation <federation_name> [clusters=<list_of_clusters>]
   ```

### Additional Requirements

- All clusters must know where each [slurmdbd](./glossary.md#slurmdbd) is.
