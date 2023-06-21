# Images

[FAQ](./faq.md) | [Troubleshooting](./troubleshooting.md) |
[Glossary](./glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Images](#images)
  - [Overview](#overview)
    - [Supported Operating Systems](#supported-operating-systems)
    - [Installed Software for HPC](#installed-software-for-hpc)
  - [Public Image](#public-image)
    - [Published Image Family](#published-image-family)
  - [Custom Image](#custom-image)
    - [Requirements](#requirements)
    - [Creation](#creation)
    - [Customize](#customize)
  - [Shielded VM Support](#shielded-vm-support)

<!-- mdformat-toc end -->

## Overview

[Google Cloud Platform](./glossary.md#gcp) instances require a source image or
source image family which the instance will boot from. SchedMD provides
[public images](#public-image) for Slurm instances, which contain an HPC
software stack for HPC ready images. Otherwise, [custom images](#custom-image)
can be created and used instead.

### Supported Operating Systems

`slurm-gcp` generally supports images built on these OS families:

| Project                | Image Family          | Arch   |
| :--------------------- | :-------------------- | :----- |
| centos-cloud           | centos-7              | x86_64 |
| cloud-hpc-image-public | hpc-centos-7          | x86_64 |
| debian-cloud           | debian-10             | x86_64 |
| debian-cloud           | debian-11             | x86_64 |
| rocky-linux-cloud      | rocky-linux-8         | x86_64 |
| ubuntu-os-cloud        | ubuntu-2004-lts       | x86_64 |
| ubuntu-os-cloud        | ubuntu-2204-lts-arm64 | ARM64  |

### Installed Software for HPC

- [Slurm](https://www.schedmd.com/downloads.php)
  - 22.05.9
- [lmod](https://lmod.readthedocs.io/en/latest/index.html)
- [openmpi](https://www.open-mpi.org/)
  - v4.1.x
- [cuda](https://developer.nvidia.com/cuda-toolkit)
  - Limited to x86_64 only
  - Latest CUDA and NVIDIA
  - NVIDIA 470 and CUDA 11.4.4 installed on hpc-centos-7-k80 variant image for
    compatibility with K80 GPUs.
- [lustre](https://www.lustre.org/)
  - Only supports x86_64
  - Client version 2.12-2.15 depending on the package available for the image
    OS.

## Public Image

SchedMD releases public images on [Google Cloud Platform](./glossary.md#gcp)
that are minimal viable images for deploying
[Slurm clusters](./glossary.md#slurm) through all method and configurations.

> **NOTE:** SchedMD generates images using the same process as documented in
> [custom images](#custom-image) but without any additional software and only
> using clean minimal base images for the source image (e.g.
> `centos-cloud/centos-7`).

### Published Image Family

|       Project        | Image Family                        | Arch   | Status         |
| :------------------: | :---------------------------------- | :----- | :------------- |
| schedmd-slurm-public | slurm-gcp-5-7-debian-11             | x86_64 | Supported      |
| schedmd-slurm-public | slurm-gcp-5-7-hpc-rocky-linux-8     | x86_64 | Supported      |
| schedmd-slurm-public | slurm-gcp-5-7-ubuntu-2004-lts       | x86_64 | Supported      |
| schedmd-slurm-public | slurm-gcp-5-7-ubuntu-2204-lts-arm64 | ARM64  | Supported      |
| schedmd-slurm-public | slurm-gcp-5-7-hpc-centos-7-k80      | x86_64 | EOL 2024-05-01 |
| schedmd-slurm-public | slurm-gcp-5-7-hpc-centos-7          | x86_64 | EOL 2024-01-01 |
| schedmd-slurm-public | slurm-gcp-5-7-centos-7              | x86_64 | EOL 2023-08-01 |
| schedmd-slurm-public | slurm-gcp-5-7-rocky-linux-8         | x86_64 | EOL 2023-06-30 |
| schedmd-slurm-public | slurm-gcp-5-7-debian-10             | x86_64 | EOL 2023-06-30 |

## Custom Image

To create [slurm_cluster](../terraform/slurm_cluster/README.md) compliant images
yourself, a custom Slurm image can be created. [Packer](./glossary.md#packer)
and [Ansible](./glossary.md#ansible) are used to orchestrate custom image
creation.

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

## Shielded VM Support

Recently published images in project `schedmd-slurm-public` support shielded VMs
without GPUs or mounting a Lustre filesystem. Both of these features require
kernel modules, which must be signed to be compatible with SecureBoot.

If you need GPUs, our published image family based on
`ubuntu-os-cloud/ubuntu-2004-lts` has signed Nvidia drivers installed and
therefore supports GPUs with SecureBoot and Shielded VMs.

If you need Lustre or GPUs on a different OS, it is possible to do this manually
with a custom image. Doing this requires

- generating a private/public key pair with openssl
- signing the needed kernel modules
- including the public key in the UEFI authorized keys `db` of the image
  - `gcloud compute images create`
  - option: `--signature-database-file`
  - Default Microsoft keys should be included as well because this overwrites
    the default key database.
  - Unfortunately, it appears that packer does not support this image creation
    option at this time, so the image creation step must be manual.

More details on this process are beyond the scope of this documentation. See
[link](https://cloud.google.com/compute/shielded-vm/docs/creating-shielded-images#adding-shielded-image)
and/or contact Google for more information.
