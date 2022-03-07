# Hybrid Cluster Guide

[FAQ](./faq.md) | [Glossary](./glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Hybrid Cluster Guide](#hybrid-cluster-guide)
  - [Overview](#overview)
  - [Terraform](#terraform)
    - [Requirements](#requirements)
    - [Setup](#setup)
      - [Maximal Configuration](#maximal-configuration)
      - [Minimal Configuration](#minimal-configuration)
  - [On-Premises](#on-premises)
    - [Requirements](#requirements-1)
    - [Node Addressing](#node-addressing)
    - [Users and Groups](#users-and-groups)
    - [Additional Configurations](#additional-configurations)

<!-- mdformat-toc end -->

## Overview

This guide focuses on setting up a hybrid [Slurm cluster](./glossary.md#slurm).
With hybrid, there are different challenges and considerations that need to be taken into account.
This guide will cover them and their recommended solutions.

There is a clear seperation of how on-prem and cloud resources are managed within your hybrid cluster.
This means that you can modify either side of the hybrid cluster without disrupting the other side!
You manage your on-prem and our [slurm cluster module](../terraform/modules/slurm_cluster/README.md) will manage the cloud.

See [Cloud Scheduling Guide](https://slurm.schedmd.com/elastic_computing.html) for additional information.

## Terraform

[Terraform](./glossary.md#terraform) is used to manage the cloud resources within your hybrid cluster and create the required files to support an on-premise controller capable of cloud bursting.
This leverages [Terraform](./glossary.md#terraform) to make cluster management composable, accountable, and consistant.
While this method can be more complex, it is a robust solution.

See the [slurm cluster module](../terraform/modules/slurm_cluster/README.md) for details.

See the [full example](../terraform/examples/slurm_cluster/hybrid/full/README.md) for an all inclusive example.
This example requires the most [roles](./glossary.md#iam-roles) but creates everything you need for a running slurm cluster.
Depending on organizational constraints, this may be a great example as a starting point and for testing.

See the [basic example](../terraform/examples/slurm_cluster/hybrid/basic/README.md) for a minimal example.
This example requires the least [roles](./glossary.md#iam-roles) but does not create everything required for running a slurm cluster.
Depending on organizational constraints, this may be a great example for production.

> **NOTE:** It is recommended to create your own [terraform](./glossary.md#terraform) project based on the examples to best fit your organizational constraints.

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
1. Deploy [full example](../terraform/examples/slurm_cluster/hybrid/full/README.md).

#### Minimal Configuration

1. Install software requirements.
1. Deploy [basic example](../terraform/examples/slurm_cluster/hybrid/basic/README.md).

## On-Premises

### Requirements

1. Communication between on-premise and [GCP](./glossary.md#gcp).
   This is commonly accomplished with a VPN of some kind -- software VPN or hardware VPN.
   The kind of VPN usually depends on throughput needs.
1. Bidirectional DNS between on-premise and [GCP](./glossary.md#gcp)
1. Open ports and [firewall rules](./glossary.md#firewall-rules).
   - Slurm communication
   - NFS and network mounts
1. slurmctld
1. slurmdbd
1. SrunPortRange

### Node Addressing

There are two options:

1. setup DNS between the on-premise network and the [GCP](./glossary.md#gcp) network
1. configure Slurm to use NodeAddr to communicate with cloud compute nodes.

In the end, the slurmctld and any login nodes should be able to communicate with cloud compute nodes, and the cloud compute nodes should be able to communicate with the controller.

- Configure DNS peering

  1. [GCP](./glossary.md#gcp) instances need to be resolvable by name from the controller and any login nodes.
  1. The controller needs to be resolvable by name from [GCP](./glossary.md#gcp) instances, or the controller IP address needs to be added to /etc/hosts.
     See [peering zones](https://cloud.google.com/dns/zones/#peering-zones) for details.

- Use IP addresses with NodeAddr

  1. Disable [cloud_dns](https://slurm.schedmd.com/slurm.conf.html#OPT_cloud_dns) in *slurm.conf*

  1. Add [cloud_reg_addrs](https://slurm.schedmd.com/slurm.conf.html#OPT_cloud_reg_addrs) to *slurm.conf*:

     ```conf
     # slurm.conf
     SlurmctldParameters=cloud_reg_addrs
     ```

  1. Disable hierarchical communication in *slurm.conf*:

     ```conf
     # slurm.conf
     TreeWidth=65533
     ```

  1. Add controller's IP address to /etc/hosts on the [custom image](./images.md#custom-images).

### Users and Groups

The simplest way to handle user synchronization in a hybrid cluster is to use [nss_slurm](https://slurm.schedmd.com/nss_slurm.html).
This permits `passwd` and `group` resolution for a job on the compute node to be serviced by the local `slurmstepd` process rather than some other network-based service.
User information is sent from the controller for each job and served by the `slurmstepd`.

[nss_slurm](https://slurm.schedmd.com/nss_slurm.html) is installed and configured on all [SchedMD public images](./images.md#public-images).

### Additional Configurations

Once you have successfully configured a hybrid [slurm_cluster](../terraform/modules/slurm_cluster/README.md) and applied the [terraform](./glossary.md#terraform) infrastructure, the necessary files will be generated at `$output_dir`.
It is recommended that `$output_dir` is equal to the path where Slurm searches for config files (e.g. `/etc/slurm`).

Follow the below steps to complete the process of configuring your on-prem controller to be able to burst into the cloud.

1. In your *slurm.conf*, include the generated *cloud.conf*:
   ```conf
   # slurm.conf
   include $output_dir/cloud.conf
   ```
1. In your *gres.conf*, include the generated *cloud_gres.conf*:
   ```conf
   # gres.conf
   include $output_dir/cloud_gres.conf
   ```
1. Add a cronjob/crontab to call slurmsync.py as SlurmUser.
   ```conf
   */1 * * * * $output_dir/slurmsync.py
   ```
1. Restart slurmctld and resolve include conflicts.
1. Test cloud bursting.
   ```sh
   scontrol update nodename=$NODENAME state=power_up reason=test
   scontrol update nodename=$NODENAME state=power_down reason=test
   ```
