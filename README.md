# Slurm on Google Cloud Platform

The following describes setting up a Slurm cluster using [Google Cloud
Platform](https://cloud.google.com), bursting out from an on-premise cluster to
nodes in Google Cloud Platform and setting a multi-cluster/federated setup with
a cluster that resides in Google Cloud Platform.

The supplied scripts can be modified to work with your environment.

SchedMD provides professional services to help you get up and running in the
cloud environment. [SchedMD Commercial Support](https://www.schedmd.com/support.php)

Issues and/or enhancement requests can be submitted to
[SchedMD's Bugzilla](https://bugs.schedmd.com).

Also, join comunity discussions on either the
[Slurm User mailing list](https://slurm.schedmd.com/mail.html) or the
[Google Cloud & Slurm Community Discussion Group](https://groups.google.com/forum/#!forum/google-cloud-slurm-discuss).


# Contents

* [Stand-alone Cluster in Google Cloud Platform](#stand-alone-cluster-in-google-cloud-platform)
  * [Install using GCP Marketplace](#install-using-gcp-marketplace)
  * [Install using Terraform](#install-using-terraform)
	* [Defining network storage mounts](#defining-network-storage-mounts)
  * [Public Slurm Images](#public-slurm-images)
	* [Hyperthreads](hyperthreads)
	* [Preinstalled Modules: OpenMPI](#preinstalled-modules-openmpi)
  * [Installing Custom Packages](#installing-custom-packages)
  * [Accessing Compute Nodes Directly](#accessing-compute-nodes-directly)
  * [OS Login](#os-login)
  * [Preemptible VMs](#preemptible-vms)
* [Hybrid Cluster for Bursting from On-Premise](#hybrid-cluster-for-bursting-from-on-premise)
  * [Node Addressing](#node-addressing)
  * [Configuration Steps](#configuration-steps)
  * [Users and Groups in a Hybrid Cluster](#users-and-groups-in-a-hybrid-cluster)
* [Multi-Cluster / Federation](#multi-cluster-federation)
* [Troubleshooting](#troubleshooting)

## Stand-alone Cluster in Google Cloud Platform

The supplied scripts can be used to create a stand-alone cluster in Google Cloud
Platform. The scripts setup the following scenario:

* 1 - controller node
* N - login nodes
* Multiple partitions with their own machine type, gpu type/count, disk size,
  disk type, cpu platform, and maximum node count.

Instances are created from images with Slurm and dependencies preinstalled. The default,
`schedmd-slurm-public/schedmd-slurm-20-11-4-hpc-centos-7`, is based on the
Google-provided HPC-optimized CentOS 7 image.

By default, `/apps` and `/home` are mounted from the controller across all instances
in the cluster. These can be overwritten, and any other controller paths or
external mounts can be added.

### Install using GCP Marketplace

See the following [page](MP_README.md) for Marketplace instructions.

### Install using Terraform

To deploy, you must have a GCP account and either have the
[GCP Cloud SDK](https://cloud.google.com/sdk/downloads) and
[Terraform](https://www.terraform.io/downloads.html)
installed on your computer or use the GCP
[Cloud Shell](https://cloud.google.com/shell/).

Steps:
1. cd to tf/examples/basic
2. Copy `basic.tfvars.example` to `basic.tfvars`
3. Edit `basic.tfvars` with the required configuration  
	See the [tf/examples/basic/io.tf](tf/examples/basic/io.tf)
	file for more detailed information on available configuration options.
4. Deploy the cluster
   ```
   $ terraform init
   $ terraform apply -var-file=basic.tfvars
   ```
5. Tearing down the cluster

   ```
   $ terraform destroy -var-file=basic.tfvars
   ```

   **NOTE:** If additional resources (instances, networks) are created other
   than the ones created from the default deployment then they will need to be
   destroyed before deployment can be removed. This includes bursted instances
   that Slurm has not yet suspended.

#### Defining network storage mounts
There are 3 types of network storage sections that can be provided to the TF
modules: `network_storage`, `login_network_storage`, and
`partitions[].network_storage`.
* `network_storage` is mounted on all instances in the cluster.
* `login_network_storage` is mounted on the controller and all login nodes.
* `partitions[].network_storage` is mounted on compute instances within the
specified partition.

All of these have the same 5 fields: 
* `server_ip`
* `remote_mount`
* `local_mount`
* `fs_type`
* `mount_options`

`server_ip` has one special value: `$controller`. This indicates that the mount is
on the controller, so the `remote_mount` path will be exported, and the `server_ip`
will be replaced with the correct hostname so all other instances can properly
access the mount.

`fs_type` can be one of: `nfs`, `cifs`, `lustre`, `gcsfuse`

### Public Slurm images
There are currently 3 public image families available for use with Slurm-GCP:  
`projects/schedmd-slurm-public/global/images/family/`  
* `schedmd-slurm-20-11-4-hpc-centos-7`  
* `schedmd-slurm-20-11-4-centos-7`  
* `schedmd-slurm-20-11-4-debian-10`

#### Hyperthreads
For now, hyperthreading is either enabled or disabled in the image. Slurm-GCP must 
know this for each compute node type when configuring the cluster so it can 
configure the correct number of CPUs.
`image_hyperthreads` must be set on the partition definition to reflect the 
state of hyperthreads in the image. If `image_hyperthreads` is set to `true`, 
and the image does not have hyperthreads enabled, the compute nodes will fail 
to report to Slurm when created.
The `hpc-centos-7` image has hyperthreads disabled.  
**NOTE:** The result of disabling hyperthreads is that half the number of CPUs will 
be usable, eg. `c2-standard-4` compute nodes will have 2 CPUs.

#### Preinstalled modules: OpenMPI
OpenMPI has been compiled to work with Slurm's srun. e.g.
```
$ module load openmpi
$ which mpicc
/apps/ompi/v4.1.x/bin/mpicc
$ mpicc mpi_hello_world.c
$ srun -N4 a.out
Hello world from processor g1-compute-0-0, rank 0 out of 4 processors
Hello world from processor g1-compute-0-3, rank 3 out of 4 processors
Hello world from processor g1-compute-0-1, rank 1 out of 4 processors
Hello world from processor g1-compute-0-2, rank 2 out of 4 processors
```

### Installing Custom Packages
   There are two files, *custom-controller-install* and *custom-compute-install*, in
   the scripts directory that can be used to add custom installations for the
   given instance type. The files will be executed during startup of the
   instance types.

   Since the custom install scripts must be run when starting bursted nodes,
   long-running customizations should be added in a custom image instead.

### Accessing Compute Nodes Directly

   There are multiple ways to connect to the compute nodes:
   1. If the compute nodes have external IPs you can connect directly to the
      compute nodes. From the [VM Instances](https://console.cloud.google.com/compute/instances)
      page, the SSH drop down next to the compute instances gives several
      options for connecting to the compute nodes.
   2. With IAP configured, you can SSH to the nodes regardless of external IPs or not.
      See https://cloud.google.com/iap/docs/enabling-compute-howto.
   3. Use Slurm to get an allocation on the nodes.
      ```
      $ srun --pty $SHELL
      [g1-login0 ~]$ srun --pty $SHELL
      [g1-compute-0-0 ~]$
      ```

### OS Login

   By default, all instances are configured with
   [OS Login](https://cloud.google.com/compute/docs/oslogin).

   > OS Login lets you use Compute Engine IAM roles to manage SSH access to
   > Linux instances and is an alternative to manually managing instance access
   > by adding and removing SSH keys in metadata.
   > https://cloud.google.com/compute/docs/instances/managing-instance-access

   This allows user uid and gids to be consistent across all instances.

   When sharing a cluster with non-admin users, the following IAM rules are
   recommended:

   1. Create a group for all users in admin.google.com.
   2. At the project level in IAM, grant the **Compute Viewer** and **Service
      Account User** roles to the group.
   3. At the instance level for each login node, grant the **Compute OS Login**
      role to the group.
      1. Make sure the **Info Panel** is shown on the right.
      2. On the compute instances page, select the boxes to the left of the
         login nodes.
      3. Click **Add Members** and add the **Compute OS Login** role to the group.
   4. At the organization level, grant the **Compute OS Login External User**
      role to the group if the users are not part of the organization.
   5. To allow ssh to login nodes without external IPs, configure IAP for the
      group.
      1. Go to the [Identity-Aware Proxy page](https://console.cloud.google.com/security/iap?_ga=2.207343252.68494128.1583777071-470618229.1575301916)
      2. Select project
      3. Click **SSH AND TCP RESOURCES** tab
      4. Select boxes for login nodes
      5. Add group as a member with the **IAP-secured Tunnel User** role
      6. Reference: https://cloud.google.com/iap/docs/enabling-compute-howto

   This allows users to access the cluster only through the login nodes.

### Preemptible VMs
   With preemptible_bursting on, when a node is found preempted, or stopped,
   the slurmsync script will mark the node as "down" and will attempt to
   restart the node. If there were any batch jobs on the preempted node, they
   will be requeued -- interactive (e.g. srun, salloc) jobs can't be requeued.

## Hybrid Cluster for Bursting from On-Premise

Bursting out from an on-premise cluster is done by configuring the
**ResumeProgram** and the **SuspendProgram** in the slurm.conf to 
*resume.py*, *suspend.py* in the scripts directory. *config.yaml* should
be configured so that the scripts can create and destroy compute instances in a
GCP project. 
See [Cloud Scheduling Guide](https://slurm.schedmd.com/elastic_computing.html)
for more information.

Pre-reqs:
1. VPN between on-premise and GCP
2. bidirectional DNS between on-premise and GCP
3. Open ports to on-premise
   1. slurmctld
   2. slurmdbd
   3. SrunPortRange
4. Open ports in GCP for NFS from on-premise

### Node Addressing  
There are two options: 1) setup DNS between the on-premise network and the GCP
network or 2) configure Slurm to use NodeAddr to communicate with cloud compute
nodes. In the end, the slurmctld and any login nodes should be able to
communicate with cloud compute nodes, and the cloud compute nodes should be
able to communicate with the controller.

* Configure DNS peering  
   1. GCP instances need to be resolvable by name from the controller and any
      login nodes.
   2. The controller needs to be resolvable by name from GCP instances, or the
      controller ip address needs to be added to /etc/hosts.
   https://cloud.google.com/dns/zones/#peering-zones  

* Use IP addresses with NodeAddr
   1. disable [cloud_dns](https://slurm.schedmd.com/slurm.conf.html#OPT_cloud_dns) in *slurm.conf*
   2. add SlurmctldParameters=[cloud_reg_addrs](https://slurm.schedmd.com/slurm.conf.html#OPT_cloud_reg_addrs) in *slurm.conf*
   3. disable hierarchical communication in *slurm.conf*: `TreeWidth=65533`
   4. add controller's ip address to /etc/hosts on compute image

### Configuration Steps
1. Create a base instance

   Create a bare image and install and configure the packages (including Slurm)
   that you are used to for a Slurm compute node. Then [create an image](https://cloud.google.com/compute/docs/images/create-delete-deprecate-private-images)
   of the base image. It's recommended to create the image in a family.

2. Create a [service account](https://cloud.google.com/iam/docs/creating-managing-service-accounts)
   and [service account key](https://cloud.google.com/docs/authentication/getting-started#creating_a_service_account)
   that will have access to create and delete instances in the remote project.

3. Install scripts

   Install the *resume.py*, *suspend.py*, *slurmsync.py*, *util.py* and
   *config.yaml.example* from the slurm-gcp repository's [scripts](scripts) directory to a
   location on the slurmctld. Rename *config.yaml.example* to *config.yaml* and
   modify the approriate values.  

   Add the path of the service account key to *google_app_cred_path* in *config.yaml*.
   
   Add the image URL (path to the image or family) to each instance defintion.

4. Modify slurm.conf:

   ```
   PrivateData=cloud
   
   SuspendProgram=/path/to/suspend.py
   ResumeProgram=/path/to/resume.py
   ResumeFailProgram=/path/to/suspend.py
   SuspendTimeout=600
   ResumeTimeout=600
   ResumeRate=0
   SuspendRate=0
   SuspendTime=300
   
   # Tell Slurm to not power off nodes. By default, it will want to power
   # everything off. SuspendExcParts will probably be the easiest one to use.
   #SuspendExcNodes=
   #SuspendExcParts=
   
   SchedulerParameters=salloc_wait_nodes
   SlurmctldParameters=cloud_dns,idle_on_node_suspend
   CommunicationParameters=NoAddrCache
   LaunchParameters=enable_nss_slurm
   
   SrunPortRange=60001-63000
   ```

5. Add a cronjob/crontab to call slurmsync.py to be called by SlurmUser.

   e.g.
   ```
   */1 * * * * /path/to/slurmsync.py
   ```

6. Test

   Try creating and deleting instances in GCP by calling the commands directly as SlurmUser.
   ```
   ./resume.py g1-compute-0-0
   ./suspend.py g1-compute-0-0
   ```

### Users and Groups in a Hybrid Cluster
The simplest way to handle user synchronization in a hybrid cluster is to use
`nss_slurm`. This permits passwd and group resolution for a job on the compute
node to be serviced by the local slurmstepd process rather than some other
network-based service. User information is sent from the controller for each
job and served by the slurm step daemon. `nss_slurm` needs to be installed on
the compute node image, which it is when the image is created with deployment
manager or Terraform. For details on how to configure `nss_slurm`, see
<https://slurm.schedmd.com/nss_slurm.html>.


## Multi-Cluster / Federation
Slurm allows the use of a central SlurmDBD for multiple clusters. By doing
this, it also allows the clusters to be able to communicate with each other.
This is done by the client commands first checking with the SlurmDBD for the
requested cluster's IP address and port which the client then uses to
communicate directly with the cluster.

Some possible scenarios:
* An on-premise cluster and a cluster in GCP sharing a single SlurmDBD.
* An on-premise cluster and a cluster in GCP each with their own SlurmDBD but
  having each SlurmDBD know about each other using
  [AccountingStorageExternalHost](https://slurm.schedmd.com/slurm.conf.html#OPT_AccountingStorageExternalHost)
  in each slurm.conf.

The following considerations are needed for these scenarios:
* Regardless of location for the SlurmDBD, both clusters need to be able to
  talk to the each SlurmDBD and controller.
  * A VPN is recommended for traffic between on-premise and the cloud.
* In order for interactive jobs (srun, salloc) to work from the login nodes to
  each cluster, the compute nodes must be accessible from the login nodes on
  each cluster.
  * It may be easier to only support batch jobs between clusters.
    * Once a batch job is on a cluster, srun functions normally.
* If a firewall exists, srun communications most likely need to be allowed
  through it. Configure SrunPortRange to define a range for ports for srun
  communications.
* Consider how to present file systems and data movement between clusters.
* **NOTE:** All clusters attached to a single SlurmDBD must share the same user
  space (e.g. same uids across all the clusters).
* **NOTE:** Either all clusters and the SlurmDBD must share the same MUNGE key
  or use a separate MUNGE key for each cluster and another key for use between
  each cluster and the SlurmDBD. In order for cross-cluster interactive jobs to
  work, the clusters must share the same MUNGE key. See the following for more
  information:  
  [Multi-Cluster Operation](https://slurm.schedmd.com/multi_cluster.html)  
  [Accounting and Resource Limits](https://slurm.schedmd.com/accounting.html)


For more information see:  
[Multi-Cluster Operation](https://slurm.schedmd.com/multi_cluster.html)  
[Federated Scheduling Guide](https://slurm.schedmd.com/federation.html)



## Troubleshooting
1. Nodes aren't bursting?
   1. Check /var/log/slurm/resume.log for any errors
   2. Try creating nodes manually by calling resume.py manually **as the
      "slurm" user**.
      * **NOTE:** If you run resume.py manually with root, subsequent calls to
	resume.py by the "slurm" user may fail because resume.py's log file
	will be owned by root.
   3. Check the slurmctld logs
      * /var/log/slurm/slurmctld.log
      * Turn on the *PowerSave* debug flag to get more information.
        e.g.
        ```
        $ scontrol setdebugflags +powersave
        ...
        $ scontrol setdebugflags -powersave
        ```
2. Cluster environment not fully coming up  
   For example:
   * Slurm not being installed
   * Compute images never being stopped
   * etc.

   1. Check syslog (/var/log/messages) on instances for any errors. **HINT:**
      search for last mention of "startup-script."
3. General debugging
   * check logs
     * /var/log/messages
     * /var/log/slurm/*.log
     * **NOTE:** syslog and all Slurm logs can be viewed in [GCP Console's Logs Viewer](https://console.cloud.google.com/logs/viewer).
   * check GCP quotas
