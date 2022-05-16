# Glossary

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Glossary](#glossary)
  - [Access Scopes](#access-scopes)
  - [Ansible](#ansible)
  - [Bigquery](#bigquery)
  - [Compute Engine](#compute-engine)
  - [Federated Cluster](#federated-cluster)
  - [Firewall Rules](#firewall-rules)
  - [GCP](#gcp)
  - [GCP Marketplace](#gcp-marketplace)
  - [IAM](#iam)
  - [IAM Roles](#iam-roles)
  - [Instance Template](#instance-template)
  - [Multi-Cluster](#multi-cluster)
  - [MUNGE](#munge)
  - [OS Login](#os-login)
  - [Packer](#packer)
  - [PackerUser](#packeruser)
  - [Packer Project](#packer-project)
  - [Preemptible VM](#preemptible-vm)
  - [Private Google Access](#private-google-access)
  - [Pub/Sub](#pubsub)
  - [Python](#python)
  - [Pip](#pip)
  - [GCP Quota](#gcp-quota)
  - [Service Account](#service-account)
  - [Secret Manager](#secret-manager)
  - [Self Link](#self-link)
  - [Slurm](#slurm)
    - [Slurmctld](#slurmctld)
    - [Slurmdbd](#slurmdbd)
    - [Slurmrestd](#slurmrestd)
    - [Slurmd](#slurmd)
    - [Slurmstepd](#slurmstepd)
  - [SPOT VM](#spot-vm)
  - [Terraform](#terraform)
  - [TerraformUser](#terraformuser)
  - [Terraform Project](#terraform-project)
  - [Terraform Registry](#terraform-registry)
  - [VM](#vm)

<!-- mdformat-toc end -->

## Access Scopes

https://cloud.google.com/compute/docs/access/service-accounts#accesscopesiam

> Access scopes are the legacy method of specifying authorization for your
> instance. They define the default OAuth scopes used in requests from the
> gcloud CLI or the client libraries.

> Access scopes apply on a per-instance basis. You set access scopes when
> creating an instance and the access scopes persists only for the life of the
> instance.

## Ansible

https://www.ansible.com/

> Red Hat® Ansible® Automation Platform is a foundation for building and
> operating automation across an organization. The platform includes all the
> tools needed to implement enterprise-wide automation.

https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html

## Bigquery

https://cloud.google.com/bigquery

> Serverless, highly scalable, and cost-effective multicloud data warehouse
> designed for business agility.

## Compute Engine

https://cloud.google.com/compute

> Secure and customizable compute service that lets you create and run virtual
> machines on Google’s infrastructure.

## Federated Cluster

https://slurm.schedmd.com/federation.html

> Slurm includes support for creating a federation of clusters and scheduling
> jobs in a peer-to-peer fashion between them. Jobs submitted to a federation
> receive a unique job ID that is unique among all clusters in the federation. A
> job is submitted to the local cluster (the cluster defined in the slurm.conf)
> and is then replicated across the clusters in the federation. Each cluster
> then independently attempts to the schedule the job based off of its own
> scheduling policies. The clusters coordinate with the "origin" cluster
> (cluster the job was submitted to) to schedule the job.

## Firewall Rules

https://cloud.google.com/vpc/docs/firewalls

> VPC firewall rules let you allow or deny connections to or from your virtual
> machine (VM) instances based on a configuration that you specify. Enabled VPC
> firewall rules are always enforced, protecting your instances regardless of
> their configuration and operating system, even if they have not started up.

## GCP

https://cloud.google.com

> Google Cloud Platform (GCP).

## GCP Marketplace

https://console.cloud.google.com/marketplace

> Marketplace lets you quickly deploy software on Google Cloud Platform.

## IAM

https://cloud.google.com/iam/docs/overview

> IAM lets you grant granular access to specific Google Cloud resources and
> helps prevent access to other resources. IAM lets you adopt the security
> principle of least privilege, which states that nobody should have more
> permissions than they actually need.

## IAM Roles

https://cloud.google.com/iam/docs/understanding-roles

> A role contains a set of permissions that allows you to perform specific
> actions on Google Cloud resources. To make permissions available to
> principals, including users, groups, and service accounts, you grant roles to
> the principals.

## Instance Template

https://cloud.google.com/compute/docs/instance-templates

> Instance templates define the machine type, boot disk image or container
> image, labels, startup script, and other instance properties. You can then use
> an instance template to create a MIG or to create individual VMs. Instance
> templates are a convenient way to save a VM instance's configuration so you
> can use it later to create VMs or groups of VMs.

## Multi-Cluster

https://slurm.schedmd.com/multi_cluster.html

> A cluster is comprised of all the nodes managed by a single slurmctld daemon.
> Slurm offers the ability to target commands to other clusters instead of, or
> in addition to, the local cluster on which the command is invoked. When this
> behavior is enabled, users can submit jobs to one or many clusters and receive
> status from those remote clusters.

## MUNGE

https://github.com/dun/munge/wiki/Man-7-munge

> MUNGE (MUNGE Uid 'N' Gid Emporium) is an authentication service for creating
> and validating user credentials. It is designed to be highly scalable for use
> in an HPC cluster environment. It provides a portable API for encoding the
> user's identity into a tamper-proof credential that can be obtained by an
> untrusted client and forwarded by untrusted intermediaries within a security
> realm. Clients within this realm can create and validate credentials without
> the use of root privileges, reserved ports, or platform-specific methods.

## OS Login

https://cloud.google.com/compute/docs/oslogin

> Use OS Login to manage SSH access to your instances using IAM without having
> to create and manage individual SSH keys. OS Login maintains a consistent
> Linux user identity across VM instances and is the recommended way to manage
> many users across multiple instances or projects.

## Packer

https://www.packer.io/

> Create identical machine images for multiple platforms from a single source
> configuration.

https://www.packer.io/downloads.html

## PackerUser

The `PackerUser` is the user who invokes the `packer` command. This user must
have correct permissions and [GCP IAM roles](#iam-roles) to create, delete, and
modify resources as defined in the [packer project](#packer-project).

## Packer Project

A packer project is any directory that contains a set of packer files
(`*.pkr.hcl`) which define providers, resources, and data.

## Preemptible VM

https://cloud.google.com/compute/docs/instances/preemptible

> Preemptible VM instances are available at much lower price—a 60-91%
> discount—compared to the price of standard VMs. However, Compute Engine might
> stop (preempt) these instances if it needs to reclaim the compute capacity for
> allocation to other VMs. Preemptible instances use excess Compute Engine
> capacity, so their availability varies with usage.

## Private Google Access

https://cloud.google.com/vpc/docs/configure-private-google-access

> Private Google Access also allows access to the external IP addresses used by
> App Engine, including third-party App Engine-based services.

## Pub/Sub

https://cloud.google.com/pubsub/docs/overview

> Pub/Sub allows services to communicate asynchronously, with latencies on the
> order of 100 milliseconds.

## Python

https://www.python.org/

https://docs.python.org/3/faq/general.html

> Python is an interpreted, interactive, object-oriented programming language.
> It incorporates modules, exceptions, dynamic typing, very high level dynamic
> data types, and classes. It supports multiple programming paradigms beyond
> object-oriented programming, such as procedural and functional programming.
> Python combines remarkable power with very clear syntax. It has interfaces to
> many system calls and libraries, as well as to various window systems, and is
> extensible in C or C++. It is also usable as an extension language for
> applications that need a programmable interface. Finally, Python is portable:
> it runs on many Unix variants including Linux and macOS, and on Windows.

## Pip

https://en.wikipedia.org/wiki/Pip\_(package_manager)

> **pip** is a package-management system written in Python used to install and
> manage software packages. It connects to an online repository of public
> packages, called the Python Package Index. pip can also be configured to
> connect to other package repositories (local or remote), provided that they
> comply to Python Enhancement Proposal 503.

## GCP Quota

https://cloud.google.com/docs/quota

> Google Cloud uses quotas to restrict how much of a particular shared Google
> Cloud resource that you can use. Each quota represents a specific countable
> resource, such as API calls to a particular service, the number of load
> balancers used concurrently by your project, or the number of projects that
> you can create.

> There are two categories for quotas:
>
> - Rate quotas are typically used for limiting the number of requests you can
>   make to an API or service. Rate quotas reset after a time interval that is
>   specific to the service—for example, the number of API requests per day.
> - Allocation quotas are used to restrict the use of resources that don't have
>   a rate of usage, such as the number of VMs used by your project at a given
>   time. Allocation quotas don't reset over time, instead you must explicitly
>   release the resource when you no longer want to use it—for example, by
>   deleting a GKE cluster.

## Service Account

https://cloud.google.com/iam/docs/service-accounts

> A service account is a special kind of account used by an application or
> compute workload, such as a Compute Engine virtual machine (VM) instance,
> rather than a person. Applications use service accounts to make authorized API
> calls, authorized as either the service account itself, or as Google Workspace
> or Cloud Identity users through domain-wide delegation.

## Secret Manager

https://cloud.google.com/secret-manager

> Secret Manager is a secure and convenient storage system for API keys,
> passwords, certificates, and other sensitive data. Secret Manager provides a
> central place and single source of truth to manage, access, and audit secrets
> across Google Cloud.

## Self Link

The URI to a resource within GCP (e.g.
`"projects/my-project/zones/us-central1/instances/my-instance"`).

## Slurm

https://slurm.schedmd.com/overview.html

> Slurm is an open source, fault-tolerant, and highly scalable cluster
> management and job scheduling system for large and small Linux clusters. Slurm
> requires no kernel modifications for its operation and is relatively
> self-contained. As a cluster workload manager, Slurm has three key functions.
> First, it allocates exclusive and/or non-exclusive access to resources
> (compute nodes) to users for some duration of time so they can perform work.
> Second, it provides a framework for starting, executing, and monitoring work
> (normally a parallel job) on the set of allocated nodes. Finally, it
> arbitrates contention for resources by managing a queue of pending work.
> Optional plugins can be used for accounting, advanced reservation, gang
> scheduling (time sharing for parallel jobs), backfill scheduling, topology
> optimized resource selection, resource limits by user or bank account, and
> sophisticated multifactor job prioritization algorithms.

### Slurmctld

https://slurm.schedmd.com/slurmctld.html

> slurmctld is the central management daemon of Slurm. It monitors all other
> Slurm daemons and resources, accepts work (jobs), and allocates resources to
> those jobs. Given the critical functionality of slurmctld, there may be a
> backup server to assume these functions in the event that the primary server
> fails.

### Slurmdbd

https://slurm.schedmd.com/slurmdbd.html

> slurmdbd provides a secure enterprise-wide interface to a database for Slurm.
> This is particularly useful for archiving accounting records.

### Slurmrestd

https://slurm.schedmd.com/slurmrestd.html

> slurmrestd is REST API interface for Slurm.

### Slurmd

https://slurm.schedmd.com/slurmd.html

> The compute node daemon for Slurm.

### Slurmstepd

https://slurm.schedmd.com/slurmstepd.html

> slurmstepd is a job step manager for Slurm. It is spawned by the slurmd daemon
> when a job step is launched and terminates when the job step does. It is
> responsible for managing input and output (stdin, stdout and stderr) for the
> job step along with its accounting and signal processing. slurmstepd should
> not be initiated by users or system administrators.

## SPOT VM

https://cloud.google.com/compute/docs/instances/spot

> Spot VMs are available at much lower price—a 60-91% discount—compared to the
> price of standard VMs. However, Compute Engine might preempt Spot VMs if it
> needs to reclaim those resources for other tasks. At this uncertain preemption
> time, Compute Engine either stops (default) or deletes your Spot VMs depending
> on your specified termination action for each VM. Spot VMs are excess Compute
> Engine capacity, so their availability varies with usage. Spot VMs do not have
> a minimum or maximum runtime.

## Terraform

https://www.terraform.io/

> Terraform is an open-source infrastructure as code software tool that provides
> a consistent CLI workflow to manage hundreds of cloud services. Terraform
> codifies cloud APIs into declarative configuration files.

## TerraformUser

The `TerraformUser` is the user who invokes the `terraform` command. This user
must have correct permissions and [GCP IAM roles](#iam-roles) to create, delete,
and modify resources as defined in the [terraform project](#terraform-project).

## Terraform Project

A terraform project is any directory that contains a set of terraform files
(`*.tf`) which define providers, resources, and data.

## Terraform Registry

https://registry.terraform.io

> Discover Terraform providers that power all of Terraform’s resource types, or
> find modules for quickly deploying common infrastructure configurations.

## VM

https://cloud.google.com/learn/what-is-a-virtual-machine

> A virtual machine (VM) is a digital version of a physical computer. Virtual
> machine software can run programs and operating systems, store data, connect
> to networks, and do other computing functions, and requires maintenance such
> as updates and system monitoring. Multiple VMs can be hosted on a single
> physical machine, often a server, and then managed using virtual machine
> software. This provides flexibility for compute resources (compute, storage,
> network) to be distributed among VMs as needed, increasing overall efficiency.
> This architecture provides the basic building blocks for the advanced
> virtualized resources we use today, including cloud computing.
