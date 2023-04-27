# High Throughput Computing (HTC) Guide

[FAQ](./faq.md) | [Troubleshooting](./troubleshooting.md) |
[Glossary](./glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [High Throughput Computing (HTC) Guide](#high-throughput-computing-htc-guide)
  - [Overview](#overview)
  - [Slurm Configurations](#slurm-configurations)
  - [slurm-gcp Configurations](#slurm-gcp-configurations)
    - [cloud.conf](#cloudconf)
  - [Example](#example)
  - [Hardware Recommendations](#hardware-recommendations)
    - [Slurmctld](#slurmctld)
    - [Slurmdbd](#slurmdbd)
  - [OS Customization](#os-customization)

<!-- mdformat-toc end -->

## Overview

This document contains slurm-gcp administrator information specifically for high
throughput computing, namely the execution of many short jobs. Getting optimal
performance for high throughput computing does require some tuning and this
document should help you off to a good start. A working knowledge of slurm-gcp
and Slurm should be considered a prerequisite for this material.

For support with Slurm and optimizing your HTC environment, please contact
[SchedMD Support](https://www.schedmd.com/support.php).

## Slurm Configurations

See
[High Throughput Computing Administration Guide](https://slurm.schedmd.com/high_throughput.html)
for the Slurm HTC guide.

## slurm-gcp Configurations

To make slurm.conf changes in slurm-gcp in accordance with HTC recommendations,
the currently supported method is to pass a slurm.conf template file into the
controller module with input variables
[\*\_tpl](../terraform/slurm_cluster/modules/slurm_controller_instance/README_TF.md#inputs).

Currently, the terraform modules expose these template files which get rendered
into the corresponding slurm configuration files:

| Template File     | Rendered File |
| ----------------- | ------------- |
| cgroup_conf_tpl   | cgroup.conf   |
| slurm_conf_tpl    | slurm.conf    |
| slurmdbd_conf_tpl | slurmdbd.conf |

Sample template files can be found [here](../etc/). Copy, modify, and pass it
into the controller module.

### cloud.conf

On controller startup, the `cloud.conf` is generated based on the terraform
configuration to support a cluster that has compute nodes in the cloud.
Moreover, nodes and partition are defined along with a number of parameters to
support cloud nodes.

- PrivateData
- LaunchParameters
- SlurmctldParameters
- SchedulerParameters
- CommunicationParameters
- GresTypes
- Prolog
- Epilog
- PrologSlurmctld
- EpilogSlurmctld
- SuspendProgram
- ResumeProgram
- ResumeFailProgram
- ResumeRate
- ResumeTimeout
- SuspendRate
- SuspendTimeout

See [setup.py](../scripts/setup.py#L147) for details.

## Example

See
[HTC example](../terraform/slurm_cluster/examples/slurm_cluster/cloud/htc/README.md).

## Hardware Recommendations

General Sizing Recommendations:

- Fewer faster cores on the slurmctld host is preferred
- Fast path to the StateSaveLocation
  - IOPS this filesystem can sustain is a major bottleneck to job throughput
- Use of array jobs instead of individual job records will help significantly as
  only one job script and environment file is saved for the entire job array

### Slurmctld

Example minimum system requirements ~ 100k jobs a day / 500 nodes.

- 16 GB RAM
  - RAM required will increase with a larger workload / node count
- Dual core CPU with high clock frequency
- Dedicated SSD or NVME (statesave)

### Slurmdbd

Example minimum system requirements ~ 100k jobs a day / 500 node

- 16-32 GB RAM
  - RAM requirement will increase with size of job store/query.
- CPU requirements are not a picky as slurmctld
- Dedicated SSD or NVME for the database

## OS Customization

OS level settings may need to be adjusted to optimize for HTC workloads or
general operation. This can be achieved though building
[custom images](./images.md#custom-image) or minimally though
[startup scripts](../terraform/slurm_cluster/README_TF.md#inputs) for the
compute instances.
