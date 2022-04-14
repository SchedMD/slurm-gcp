# Images

[FAQ](./faq.md) | [Glossary](./glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Images](#images)
  - [Overview](#overview)
    - [Installed Software for HPC](#installed-software-for-hpc)
  - [Public Image](#public-image)
  - [Custom Image](#custom-image)
    - [Requirements](#requirements)
    - [Creation](#creation)
    - [Customize](#customize)

<!-- mdformat-toc end -->

## Overview

[Google Cloud Platform](./glossary.md#gcp) instances require a source image or
source image family which the instance will boot from. SchedMD provides
[public images](#public-image) for Slurm instances, which contain an HPC
software stack for HPC ready images. Otherwise, [custom images](#custom-image)
can be created and used instead.

### Installed Software for HPC

- [lmod](https://lmod.readthedocs.io/en/latest/index.html)
- [openmpi](https://www.open-mpi.org/)
- [cuda](https://developer.nvidia.com/cuda-toolkit)

## Public Image

SchedMD releases public images on [Google Cloud Platform](./glossary.md#gcp)
that are minimal viable images for deploying
[Slurm clusters](./glossary.md#slurm) through all method and configurations.

We officially support images built on these OS families:

- RHEL
- CentOS
- Debian
- Ubuntu

Support OS versions may vary with family.

> **NOTE:** SchedMD generated images using the same process as for
> [custom images](#custom-image) but without any additional software and only
> using clean minimal base images for the source image (e.g.
> `centos-cloud/centos-7`).

## Custom Image

To create [slurm_cluster](../terraform/modules/slurm_cluster/README.md)
compliant images yourself, a custom Slurm image can be created.
[Packer](./glossary.md#packer) and [Ansible](./glossary.md#ansible) are used to
orchestrate custom image creation.

Custom images can be built from a supported private or public image (e.g.
hpc-centos-7, centos-7). Additionally, ansible roles or scripts can be added
into the provisioning process to install custom software and configure the
custom Slurm image.

### Requirements

- [Packer](./glossary.md#packer)
- [Ansible](./glossary.md#ansible)

### Creation

Install software dependencies and build images from configation.

See [slurm-gcp packer project](../packer/README.md) for details.

### Customize

Before you build your images with [packer](./glossary.md#packer), you can modify
how the build will happen. Custom packages and other image configurations can be
added by a few methods. All methods below may be used together in any
combination, if desired.

- Role [scripts](./ansible/roles/scripts) runs all scripts globbed from
  [scripts.d](../ansible/scripts.d). This method is intended for simple
  configuration scripts.
- Image configuration can be extended by specifying extra custom playbooks using
  the input variable `extra_ansible_provisioners`. These playbooks will be
  applied after Slurm installation is complete. For example, the following
  configuration will run a playbook without any dependencies on extra Ansible
  Galaxy roles:
  ```hcl
  extra_ansible_provisioners = [
    {
      playbook_file   = "/home/username/playbooks/custom.yaml"
      galaxy_file     = null
      extra_arguments = ["-vv"]
      user            = null
    },
  ]
  ```
- The Slurm image can be built on top of an existing image. Configure the
  pkrvars file with `source_image` or `source_image_family` pointing to your
  image. This is intended for more complex configurations because of workflow or
  pipelines.
