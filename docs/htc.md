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
