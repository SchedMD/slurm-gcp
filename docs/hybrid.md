# Hybrid Cluster Guide

[FAQ](./faq.md) | [Troubleshooting](./troubleshooting.md) |
[Glossary](./glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Hybrid Cluster Guide](#hybrid-cluster-guide)
  - [Overview](#overview)
    - [Background](#background)
  - [Terraform](#terraform)
    - [Quickstart Examples](#quickstart-examples)
  - [On-Premises](#on-premises)
    - [Requirements](#requirements)
    - [Node Addressing](#node-addressing)
    - [Users and Groups](#users-and-groups)
    - [Manual Configurations](#manual-configurations)
    - [Manage Secrets](#manage-secrets)
      - [Considerations](#considerations)

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

### Background

[Terraform](./glossary.md#terraform) is used to setup and manage most cloud
resources for your hybrid cluster. It will ensure that the cloud contains
resources as described in your
[terraform project](./glossary.md#terraform-project).

We provide terraform modules that support a hybrid cluster use case.
Specifically,
[slurm_controller_hybrid](../terraform/slurm_cluster/modules/slurm_controller_hybrid/README.md)
is responsible for generating slurm configuration files based upon your
configurations and our cloud scripts (e.g. `ResumeProgram`, `SuspendProgram`)
for your on-premise controller to use.

There are a set of scripts and files that support the functionality of creating
and terminating nodes in the cloud:

- `cloud_gres.conf`
  - Contains Slurm GRES configuration lines about cloud compute GRES resources.
  - To be included in your `gres.conf`.
- `cloud.conf`
  - Contains Slurm configuration lines to support a hybrid/cloud environment.
  - To be included in your `slurm.conf`.
  - **WARNING:** Certain lines may need reconciliation with your `slurm.conf`
    (e.g. `SlurmctldParameters`).
- `config.yaml`
  - Encodes information about your configuration and compute resources for
    `resume.py` and `suspend.py`.
- `resume.py`
  - `ResumeProgram` in `slurm.conf`.
  - Creates compute node resources based upon Slurm job allocation and
    configured compute resources.
- `slurmsync.py`
  - Synchronizes the Slurm state and the GCP state, reducing discrepencies from
    manual admin activity or other edge cases.
  - May update Slurm node states, create or destroy GCP compute resources or
    other script managed GCP resources.
  - To be run under `crontab` or `systemd` on an interval.
- `startup.sh`
  - Compute node startup script.
- `suspend.py`
  - `SuspendProgram` in `slurm.conf`.
- `util.py`
  - Contains utility functions for the other python scripts.

The compute resources in GCP use
[configless mode](https://slurm.schedmd.com/configless_slurm.html) to manage
their `slurm.conf`, by default.

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

Alternatively, see
[HPC Blueprints](https://cloud.google.com/hpc-toolkit/docs/setup/hpc-blueprint)
for
[HPC Toolkit](https://cloud.google.com/blog/products/compute/new-google-cloud-hpc-toolkit)
examples.

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
generated at `$output_dir`. Should another machine be the TerraformHost or
non-SlurmUser be the TerraformUser, then set `$install_dir` to the intended
directory where the generated files will be deployed on the Slurm controller
(e.g. `var.install_dir = "/etc/slurm"`).

Follow the below steps to complete the process of configuring your on-prem
controller to be able to burst into the cloud.

1. Configure terraform modules (e.g. slurm_cluster; slurm_controller_hybrid)
   with desired configurations.
1. Apply terraform project and its configuration.
   ```sh
   terraform init
   terraform apply
   ```
1. The `$output_dir` and its contents should be owned by the `SlurmUser`, eg.
   ```sh
   chown -R slurm:slurm $output_dir
   ```
1. Move files from `$output_dir` on TerraformHost to `$install_dir` of
   SlurmctldHost and make sure SlurmUser owns the files.
   ```sh
   scp ${output_dir}/* ${SLURMCTLD_HOST}:${install_dir}/
   ssh $SLURMCTLD_HOST
   sudo chown -R ${SLURM_USER}:${SLURM_USER} $output_dir
   ```
1. In your *slurm.conf*, include the generated *cloud.conf*:
   ```conf
   # slurm.conf
   include $install_dir/cloud.conf
   ```
1. In your *gres.conf*, include the generated *cloud_gres.conf*:
   ```conf
   # gres.conf
   include $install_dir/cloud_gres.conf
   ```
1. Add a cronjob/crontab to call slurmsync.py as SlurmUser.
   ```conf
   */1 * * * * $install_dir/slurmsync.py
   ```
1. Restart slurmctld and resolve include conflicts.
1. Test cloud bursting.
   ```sh
   scontrol update nodename=$NODENAME state=power_up reason=test
   scontrol update nodename=$NODENAME state=power_down reason=test
   ```

### Manage Secrets

Additionally, [MUNGE](./glossary.md#munge) secrets must be consistant across the
cluster. There are a few safe ways to deal with munge.key distribution:

- Use NFS to mount `/etc/munge` from the controller (default behavior).
- Create a [custom image](./images.md#custom-image) that contains the
  `munge.key` for your cluster.

Regardless of chosen secret delivery system, tight access control is required to
maintain the security of your cluster.

#### Considerations

Should NFS or another shared filesystem method be used, then controlling
connections to the munge NFS is critical.

- Isolate the cloud compute nodes of the cluster into their own project, VPC,
  and subnetworks. Use project or network peering to enable access to other
  cloud infrastructure in a controlled mannor.
- Setup firewall rules to control ingress and egress to the controller such that
  only trusted machines or networks use its NFS.
- Only allow trusted private address (ranges) for communication to the
  controller.

Should secrets be 'baked' into an image, then controlling deployment of images
is critical.

- Only cluster admins or sudoer's should be allowed to deploy those images.
- Never allow regular users to gain sudo privledges.
- Never allow export/download of image.
