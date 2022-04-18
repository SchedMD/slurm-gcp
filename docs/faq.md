# Frequently Asked Questions (FAQ)

[Slurm FAQ](https://slurm.schedmd.com/faq.html)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Frequently Asked Questions (FAQ)](#frequently-asked-questions-faq)
  - [For Management](#for-management)
    - [Why should I use Slurm or other Free Open Source Software (FOSS)?](#why-should-i-use-slurm-or-other-free-open-source-software-foss)
    - [Why should I use `slurm-gcp`?](#why-should-i-use-slurm-gcp)
    - [How do I get support for `slurm-gcp` and `Slurm`?](#how-do-i-get-support-for-slurm-gcp-and-slurm)
  - [For Users](#for-users)
    - [Where can I find the Slurm logs?](#where-can-i-find-the-slurm-logs)
    - [How do I move data for a job?](#how-do-i-move-data-for-a-job)
    - [How do I connect to Slurm instances?](#how-do-i-connect-to-slurm-instances)
  - [For Administrators](#for-administrators)
    - [How do I contribute to `slurm-gcp` or `slurm`?](#how-do-i-contribute-to-slurm-gcp-or-slurm)
    - [How do I use Terraform?](#how-do-i-use-terraform)
    - [How do I modify Slurm config files?](#how-do-i-modify-slurm-config-files)
    - [Why did setup.py fail?](#why-did-setuppy-fail)
    - [How do I reduce compute costs?](#how-do-i-reduce-compute-costs)
    - [How do I limit user access to only using login nodes?](#how-do-i-limit-user-access-to-only-using-login-nodes)
    - [What Slurm image do I use for production?](#what-slurm-image-do-i-use-for-production)
    - [What operating systems can I use `slurm-gcp` with?](#what-operating-systems-can-i-use-slurm-gcp-with)

<!-- mdformat-toc end -->

## For Management

### Why should I use Slurm or other Free Open Source Software (FOSS)?

https://slurm.schedmd.com/faq.html#foss

> Free Open Source Software (FOSS) does not mean that it is without cost. It
> does mean that the you have access to the code so that you are free to use it,
> study it, and/or enhance it. These reasons contribute to Slurm (and FOSS in
> general) being subject to active research and development worldwide,
> displacing proprietary software in many environments. If the software is large
> and complex, like Slurm or the Linux kernel, then while there is no license
> fee, its use is not without cost.

### Why should I use `slurm-gcp`?

This is the official and supported solution from
[SchedMD](https://www.schedmd.com/) in partnership with
[Google](https://about.google/) for [Slurm](./glossary.md#slurm) on
[Google Cloud Platform](./glossary.md#gcp).

`slurm-gcp` provides [terraform](./glossary.md#terraform) modules. This make
standing up a cluster easy and will integrate into your existing infrastructure.

### How do I get support for `slurm-gcp` and `Slurm`?

Please visit [SchedMD Support](https://www.schedmd.com/support.php) and reach
out. Tickets can be submitted via
[SchedMD's Bugzilla](https://bugs.schedmd.com).

## For Users

### Where can I find the Slurm logs?

- Check the
  [GCP Console Logs Viewer](https://console.cloud.google.com/logs/viewer).
- On Slurm cloud nodes, check `/var/log/slurm/*.log`.
- Otherwise check `/var/log/messages` (RHEL/CentOS) or `/var/log/syslog`
  (Debian/Ubuntu).

### How do I move data for a job?

Data can be migrated to and from external sources using a worflow of dependant
jobs. A [workflow submission script](../jobs/submit_workflow.py.py) and
[helper jobs](../jobs/data_migrate/) are provided. See
[README](../jobs/README.md) for more information.

### How do I connect to Slurm instances?

- If the compute nodes have external IPs you can connect directly to the compute
  nodes. From the
  [VM Instances](https://console.cloud.google.com/compute/instances) page, the
  SSH drop down next to the compute instances gives several options for
  connecting to the compute nodes.

- With [IAP](https://cloud.google.com/iap/docs/enabling-compute-howto) enabled,
  you can SSH to the nodes regardless of external IPs or not.

- Use Slurm to get an allocation on the nodes.

  For Example:

  ```sh
  $ srun --pty $SHELL
  [g1-debug-test-0 ~]$

  ```

## For Administrators

### How do I contribute to `slurm-gcp` or `slurm`?

Enhancement requests can be submitted to
[SchedMD's Bugzilla](https://bugs.schedmd.com).

### How do I use Terraform?

Please see
[Terraform documentation](https://learn.hashicorp.com/collections/terraform/gcp-get-started).

For the [Slurm terraform modules](../terraform/modules/), please refer to their
module API as documented in their README's. Additionally, please see the
[Slurm terraform examples](../terraform/examples/) for sample usage.

### How do I modify Slurm config files?

Presuming
[slurm_cluster terraform module](../terraform/modules/slurm_cluster/README.md)
was used to deploy the cluster, see
[input parameters](../terraform/modules/slurm_cluster/README_TF.md#inputs):

- slurm_conf_tpl
- cgroup_conf_tpl
- slurmdbd_conf_tpl

### Why did setup.py fail?

Check the `setup.log` at `/slurm/scripts/setup.log` for details.

### How do I reduce compute costs?

- In `partition_conf`, set a lower `SuspendTime` for a given
  [slurm_partition](../terraform/modules/slurm_partition/README.md).

  For example:

  ```hcl
  partition_conf = {
    SuspendTime = 120
  }
  ```

- For compute nodes within a given
  [slurm_partition](../terraform/modules/slurm_partition/README.md), use
  [preemptible VM](./glossary.md#preemptible-vm) instances.

  For example:

  ```hcl
  partition_nodes = [
    {
      ...
      preemptible = true
      ...
    }
  ]
  ```

- For compute nodes within a given
  [slurm_partition](../terraform/modules/slurm_partition/README.md), use
  [SPOT VM](./glossary.md#spot-vm) instances.

  For example:

  ```hcl
  partition_nodes = [
    {
      ...
      enable_spot_vm = true
      ...
    }
  ]
  ```

### How do I limit user access to only using login nodes?

By default, all instances are configured with
[OS Login](./glossary.md#os-login). This keeps UID and GID of users consistant
accross all instances and allows easy user control with
[IAM Roles](./glossary.md#iam-roles).

1. Create a group for all users in `admin.google.com`.
1. At the project level in IAM, grant the **Compute Viewer** and **Service
   Account User** roles to the group.
1. At the instance level for each login node, grant the **Compute OS Login**
   role to the group.
1. Make sure the **Info Panel** is shown on the right.
1. On the compute instances page, select the boxes to the left of the login
   nodes.
1. Click **Add Members** and add the **Compute OS Login** role to the group.
1. At the organization level, grant the **Compute OS Login External User** role
   to the group if the users are not part of the organization.
1. To allow ssh to login nodes without external IPs, configure IAP for the
   group.
1. Go to the
   [Identity-Aware Proxy page](https://console.cloud.google.com/security/iap?_ga=2.207343252.68494128.1583777071-470618229.1575301916)
1. Select project
1. Click **SSH AND TCP RESOURCES** tab
1. Select boxes for login nodes
1. Add group as a member with the **IAP-secured Tunnel User** role. Please see
   [Enabling IAP for Compute Engine](https://cloud.google.com/iap/docs/enabling-compute-howto)
   for mor information.

### What Slurm image do I use for production?

By default, the [slurm_cluster](../terraform/modules/slurm_cluster/README.md)
terraform module uses the latest Slurm image family (e.g.
`schedmd-v5-slurm-21-08-6-hpc-centos-7`). As new Slurm image families are
released, coenciding with periodic Slurm releases, the terraform module will be
updated to track the newest image family by setting it as the new default. This
update can be considered a breaking change.

In a production setting, it is recommended to explicitly set an image family.
Doing so will prevent `slurm-gcp` changes to the default image family from
negatively impacting your cluster. Moreover, the controller and all other
instances may be force replaced (destroyed, then deployed) when
`terraform apply` detects that the image family of Slurm instances has changed.

Optionally, you may generate and use your own Slurm images. See
[custom image creation](./images.md#custom-image) for more information.

### What operating systems can I use `slurm-gcp` with?

You may use any OS supported by the image build process.

See [image docs](./images.md#overview) for more information.
