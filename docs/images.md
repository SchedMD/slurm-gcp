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
[public images](#public-image) for slurm instances, which contain an HPC
software stack for HPC ready images. Otherwise, [custom images](#custom-image)
can be created and used instead.

### Installed Software for HPC

- [lmod](https://lmod.readthedocs.io/en/latest/index.html)
- [openmpi](https://www.open-mpi.org/)
- [cuda](https://developer.nvidia.com/cuda-toolkit)

## Public Image

SchedMD releases public images on [Google Cloud Platform](./glossary.md#gcp)
that are minimal viable images for deploying
[slurm clusters](./glossary.md#slurm) through all method and configurations.

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

To create minimal viable images for slurm cluster yourself, a custom image can
be created. [Packer](./glossary.md#packer) and [Ansible](./glossary.md#ansible)
are used to orchestrate custom image creation.

Custom images can be built from an existing private image or another supported
public image.

### Requirements

- [Packer](./glossary.md#packer)
- [Ansible](./glossary.md#ansible)

### Creation

```sh
# move to packer dir
cd ${slurm-gcp}/packer

# copy and edit packer configuration
cp example.pkrvars.hcl vars.pkrvars.hcl
vim vars.pkrvars.hcl

# build with packer
packer init .
packer build -var-file=vars.pkrvars.hcl .
```

*Note*: the process above will install a Google Cloud Ansible role on your local
workstation, most likely under `~/.ansible`.

### Customize

Before you build your images with [packer](./glossary.md#packer), you can modify
how the build will happen. Custom packages and other image configurations can be
added by a few methods. All methods below may be used together in any
combination, if desired.

- Role [scripts](./ansible/roles/scripts) runs all scripts globbed from
  [scripts.d](../ansible/scripts.d). This method is intended for simple
  configuration scripts.
- Image configuration can be extended via ansible roles. Create more ansible
  roles, as desired, and add them to the
  [playbook.yml](../ansible/playbook.yml). This is intended for more complex or
  ansible-based configurations.
- The Slurm image can be built on top of an existing image. Configure the
  pkrvars file with `source_image` or `source_image_family` pointing to your
  image. This is intended for more complex configurations because of workflow or
  pipelines.
