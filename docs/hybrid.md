# Hybrid Cluster Guide

[FAQ](./faq.md) | [Troubleshooting](./troubleshooting.md) |
[Glossary](./glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Hybrid Cluster Guide](#hybrid-cluster-guide)
  - [Overview](#overview)
  - [Terraform](#terraform)
    - [Quickstart Examples](#quickstart-examples)
  - [On-Premises](#on-premises)
    - [Requirements](#requirements)
    - [Node Addressing](#node-addressing)
    - [Users and Groups](#users-and-groups)
    - [Manual Configurations](#manual-configurations)

<!-- mdformat-toc end -->

## Overview

This guide focuses on setting up a hybrid [Slurm cluster](./glossary.md#slurm).
With hybrid, there are different challenges and considerations that need to be
taken into account. This guide will cover them and their recommended solutions.

There is a clear seperation of how on-prem and cloud resources are managed
within your hybrid cluster. This means that you can modify either side of the
hybrid cluster without disrupting the other side! You manage your on-prem and
our [Slurm cluster module](../terraform/slurm_cluster/README.md) will manage the
cloud.

See [Cloud Scheduling Guide](https://slurm.schedmd.com/elastic_computing.html)
for additional information.

> *NOTE*: The [manual configurations](#manual-configurations) are required to
> finish the hybrid setup.

## Terraform

[Terraform](./glossary.md#terraform) is used to manage the cloud resources
within your hybrid cluster. The
[slurm_cluster](../terraform/slurm_cluster/README.md) module, when in hybrid
mode, creates the required files to support an on-premise controller capable of
cloud bursting.

See the [Slurm cluster module](../terraform/slurm_cluster/README.md) for
details.

If you are unfamiliar with [terraform](./glossary.md#terraform), then please
checkout out the [documentation](https://www.terraform.io/docs) and
[starter guide](https://learn.hashicorp.com/collections/terraform/gcp-get-started)
to get you familiar.

### Quickstart Examples

See the
[full cluster example](../terraform/slurm_cluster/examples/slurm_cluster/hybrid/full/README.md)
for a great example to get started with. It will create all the infrastructure,
service accounts and IAM to minimally support a Slurm cluster. The
[TerraformUser](./glossary.md#terraformuser) will require more
[roles](./glossary.md#iam-roles) to create the other supporting resources. You
can configure certain elements of the example cluster, which is useful for
testing.

See the
[basic cluster example](../terraform/slurm_cluster/examples/slurm_cluster/hybrid/basic/README.md)
for a great example to base a production configuration off of. It provides the
bare minimum and leaves the rest to you. This allows for fine grain control over
the cluster environment and removes [role](./glossary.md#iam-roles) requirements
from the [TerraformUser](./glossary.md#terraformuser). You can configure certain
elements of the example cluster, which is useful for testing.

> **NOTE:** It is recommended to use the
> [slurm_cluster module](../terraform/slurm_cluster/README.md) in your own
> [terraform project](./glossary.md#terraform-project). It may be useful to copy
> and modify one of the provided examples.

## On-Premises

### Requirements

1. Communication between on-premise and [GCP](./glossary.md#gcp). This is
   commonly accomplished with a VPN of some kind -- software VPN or hardware
   VPN. The kind of VPN usually depends on throughput needs.
1. Bidirectional DNS between on-premise and [GCP](./glossary.md#gcp)
1. Open ports and [firewall rules](./glossary.md#firewall-rules).
   - Slurm communication
   - NFS and network mounts
1. slurmctld
1. slurmdbd
1. SrunPortRange

### Node Addressing

There are two options:

1. setup DNS between the on-premise network and the [GCP](./glossary.md#gcp)
   network
1. configure Slurm to use NodeAddr to communicate with cloud compute nodes.

In the end, the slurmctld and any login nodes should be able to communicate with
cloud compute nodes, and the cloud compute nodes should be able to communicate
with the controller.

- Configure DNS peering

  1. [GCP](./glossary.md#gcp) instances need to be resolvable by name from the
     controller and any login nodes.
  1. The controller needs to be resolvable by name from [GCP](./glossary.md#gcp)
     instances, or the controller IP address needs to be added to /etc/hosts.
     See [peering zones](https://cloud.google.com/dns/zones/#peering-zones) for
     details.

- Use IP addresses with NodeAddr

  1. Disable
     [cloud_dns](https://slurm.schedmd.com/slurm.conf.html#OPT_cloud_dns) in
     *slurm.conf*

  1. Add
     [cloud_reg_addrs](https://slurm.schedmd.com/slurm.conf.html#OPT_cloud_reg_addrs)
     to *slurm.conf*:

     ```conf
     # slurm.conf
     SlurmctldParameters=cloud_reg_addrs
     ```

  1. Disable hierarchical communication in *slurm.conf*:

     ```conf
     # slurm.conf
     TreeWidth=65533
     ```

  1. Add controller's IP address to /etc/hosts on the
     [custom image](./images.md#custom-images).

### Users and Groups

The simplest way to handle user synchronization in a hybrid cluster is to use
[nss_slurm](https://slurm.schedmd.com/nss_slurm.html). This permits `passwd` and
`group` resolution for a job on the compute node to be serviced by the local
`slurmstepd` process rather than some other network-based service. User
information is sent from the controller for each job and served by the
`slurmstepd`.

[nss_slurm](https://slurm.schedmd.com/nss_slurm.html) is installed and
configured on all [SchedMD public images](./images.md#public-images).

### Manual Configurations

Once you have successfully configured a hybrid
[slurm_cluster](../terraform/slurm_cluster/README.md) and applied the
[terraform](./glossary.md#terraform) infrastructure, the necessary files will be
generated at `$output_dir`. It is recommended that `$output_dir` is equal to the
path where Slurm searches for config files (e.g. `/etc/slurm`).

Follow the below steps to complete the process of configuring your on-prem
controller to be able to burst into the cloud.

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
1. The `$output_dir` and its contents should be owned by the `SlurmUser`, eg.
   ```sh
   chown -R slurm: $output_dir
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
