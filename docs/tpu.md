# TPU setup guide

[FAQ](./faq.md) | [Troubleshooting](./troubleshooting.md) |
[Glossary](./glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [TPU setup guide](#tpu-setup-guide)
  - [Overview](#overview)
  - [Supported TPU types](#supported-tpu-types)
  - [Supported Tensorflow versions](#supported-tensorflow-versions)
  - [Slurm-gcp compatiblity matrix](#slurm-gcp-compatiblity-matrix)
  - [Terraform](#terraform)
    - [Quickstart Examples](#quickstart-examples)
  - [TPU example job](#tpu-example-job)
  - [Multi-rank TPU nodes](#multi-rank-tpu-nodes)
  - [Usage information](#usage-information)
    - [Heterogeneous jobs](#heterogeneous-jobs)
    - [Static TPU nodes](#static-tpu-nodes)

<!-- mdformat-toc end -->

## Overview

> **NOTE:** Please be aware that TPU support is currently in beta testing. While
> we have put significant effort into ensuring its functionality and stability,
> there might still be some undiscovered issues or bugs.

This guide focuses on setting up a tpu nodeset for a Slurm cloud cluster. But
first it is important to take into account the following considerations.

- A partition cannot contain simultaneously a normal nodeset and a tpu nodeset.
- TPU nodes are expected to only run one job simultaneously, this is due to the
  fact that TPU devices cannot be constrained individually for every job.
- TPU nodes take more time to spin up than regular nodes, this is reflected in
  the partition ResumeTimeout and SuspendTimeout that contains TPU nodes.
- Slurm is executed in TPU nodes using a docker container.
- TPU nodes in Slurm will have different name that the one seen in GCP, that is
  because TPU names cannot be choosen or known before starting them up.
- python 3.7 or above is needed for the TPU API module to work. In consequence
  TPU nodes will not work with all the OS, like for example CentOS 7, see more
  in the [compatibility matrix](#slurm-gcp-compatiblity-matrix).

TPUs are configured in Slurm with what is called a nodeset_tpu, this is like a
regular nodeset but for TPU nodes, and it takes into account the differences
between both nodesets as well as the considerations stated above. This is
configured in terraform modules slurm_cluster and slurm_nodeset_tpu.

## Supported TPU types

At this moment the following tpu types are supported:

- v2-8
- v2-32
- v3-8

## Supported Tensorflow versions

At this moment the following tensorflow versions are supported:

- 2.12.0

## Slurm-gcp compatiblity matrix

Due to the fact that the TPU support has some requirements as having python >=
3.7 installed not all the OS support it, this table can be used to see the
compatibility between TPU and slurm-gcp images, while TPU support is in beta
state we will also include if it is tested or not.

|       Project        | Image Family                        | Arch   | TPU Status  |
| :------------------: | :---------------------------------- | :----- | :---------- |
| schedmd-slurm-public | slurm-gcp-6-1-debian-11             | x86_64 | Untested    |
| schedmd-slurm-public | slurm-gcp-6-1-hpc-rocky-linux-8     | x86_64 | Tested      |
| schedmd-slurm-public | slurm-gcp-6-1-ubuntu-2004-lts       | x86_64 | Untested    |
| schedmd-slurm-public | slurm-gcp-6-1-ubuntu-2204-lts-arm64 | ARM64  | Untested    |
| schedmd-slurm-public | slurm-gcp-6-1-hpc-centos-7-k80      | x86_64 | Unsupported |
| schedmd-slurm-public | slurm-gcp-6-1-hpc-centos-7          | x86_64 | Unsupported |

## Terraform

Terraform is used for creating the configuration for Slurm to spin up TPU nodes.

See the [slurm_cluster module](../terraform/slurm_cluster/README.md) and the
[slurm_nodeset_tpu module](../terraform/slurm_cluster/modules/slurm_nodeset_tpu/README.md)
for details.

If you are unfamiliar with [terraform](./glossary.md#terraform), then please
checkout out the [documentation](https://www.terraform.io/docs) and
[starter guide](https://learn.hashicorp.com/collections/terraform/gcp-get-started)
to get you familiar.

### Quickstart Examples

See the
[simple_cloud_tpu](../terraform/slurm_cluster/examples/slurm_cluster/simple_cloud_tpu/README.md)
example for an extensible and robust example. It can be configured to handle
creation of all supporting resources (e.g. network, service accounts) or leave
that to you. Slurm can be configured with partitions and nodesets as desired.

> **NOTE:** It is recommended to use the
> [slurm_cluster module](../terraform/slurm_cluster/README.md) in your own
> [terraform project](./glossary.md#terraform-project). It may be useful to copy
> and modify one of the provided examples.

Alternatively, see
[HPC Blueprints](https://cloud.google.com/hpc-toolkit/docs/setup/hpc-blueprint)
for
[HPC Toolkit](https://cloud.google.com/blog/products/compute/new-google-cloud-hpc-toolkit)
examples.

## TPU example job

A TPU example job can be found in the jobs folder in this repository, called
tpu.sh, this will execute the python script tpu.py, with the corresponding
flags, by default it will print the tensorflow version and the number of working
TPU chips in the system, in case that you are testing a multi-rank TPU (more on
them in the next chapter) you can call the script with the parameter "multi",
this will also show the worker_id of the vm you are currently testing on.

## Multi-rank TPU nodes

Big TPU nodes like v2-32, v3-1024 and in general any TPU node with more than 8
TPU cores will have more than one virtual-machine in it, this causes a
discrepancy between GCP TPU nodes and slurm nodes in order to work with that
slurm-gcp does the following:

- calculates the 'vmcount' for each TPU node type, that is the number of virtual
  machines that each GCP TPU node will have, for example for TPU type v2-32 this
  will be 4, as you will find 4 virtual machines in the TPU. This is also stated
  as ranks or TPU workers.
- creates a network topology file that groups all the different slurm TPU nodes
  with their corresponding GCP TPU node, for example if we have 8 slurm TPU
  nodes that have a 'vmcount' of 4, we will have 2 groups stated in this
  topology file.
- enables a lua jobsubmitplugin, this will make that at each jobsubmission the
  following is done:
  - check the 'vmcount' (vmcount is the number of virtualmachines per GCP TPU
    node) of the partition and increase the requested number of nodes
    accordingly.
  - set the --switch parameter to the original number of nodes requested, this
    will use the previously stated network topology file to ensure that all the
    slurm nodes belong to the same TPU group.
- In the resume.py script the vmcount will be queried in order to know how to
  handle the TPU creation of the nodes. The first slurm node will be used to
  name the GCP TPU node, when the TPU node is created, the worker IPs will be
  retrieved and all the slurm nodes will be mapped to these different IPs of the
  TPU worker vm's in the node, this mapping will be also noted in the instance
  metadata for the workers node to retrieve and start slurm accordingly.
- In suspend.py only the main node of the TPU (the one which has the same name
  in slurm and in the GCP console) will be taken into account, all the others
  will be considered "phantom nodes" as they do not map to any cloud resource.

## Usage information

### Heterogeneous jobs

In order to be able to execute jobs on both the TPU nodes and regular nodes you
need to have in your slurm-gcp configuration a regular nodes partition and a TPU
nodes partition.

Assuming that the normal nodes partition name is "normal", and the TPU nodes
partition name is "tpu" a job of the script "sbatch_script.sh" that uses both
would be like this:

> sbatch -p normal -N 1 : -p tpu -N 1 sbatch_script.sh

This will allocate a node in the normal partition and a node in the tpu
partition, both in the same heterogenous job.

### Static TPU nodes

Static TPU nodes can be configured the same way as regular nodes are, stating
the count of it in "node_count_static" variable of each nodeset_tpu.

<!-- Links -->
