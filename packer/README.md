# Packer

[FAQ](../docs/faq.md) | [Glossary](../docs/glossary.md)

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Packer](#packer)
  - [Overview](#overview)
  - [Usage](#usage)
  - [Dependencies](#dependencies)

<!-- mdformat-toc end -->

## Overview

Image creation is handled by [packer](./glossary.md#packer) and
[ansible](../docs/glossary.md#ansible). This
[packer project](../docs/glossary.md#packer-project) enables you to create Slurm
cluster images with ease.

## Usage

Modify [example.pkrvars.hcl](./example.pkrvars.hcl) with required and desired
values.

Then perform the following commands on the
[packer project](../docs/glossary.md#packer-project) root directory:

- `packer init .` to get the plugins
- `packer validate -var-file=example.pkrvars.hcl .` to validate the
  configuration
- `packer build -var-file=example.pkrvars.hcl .` to run the image build process

## Dependencies

- [ansible](../docs/glossary.md#ansible)
  - Install as a system package, to the user (see below), or in a
    [virtualenv](https://virtualenv.pypa.io/en/latest/)
  - `pip3 install -r requirements.txt --user`
- [packer](../docs/glossary.md#packer)
  - [download](https://www.packer.io/downloads.html)
