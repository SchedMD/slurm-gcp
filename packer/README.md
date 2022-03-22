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

Modify [example.pkr.hcl](./example.pkr.hcl) with required and desired values.

Then perform the following commands on the
[packer project](../docs/glossary.md#packer-project) root directory:

- `packer init .` to get the plugins
- `packer validate -var-file=example.pkr.hcl .` to validate the configuration
- `packer build -var-file=example.pkr.hcl .` to run the image build process

## Dependencies

- [ansible](../docs/glossary.md#ansible)
- [packer](../docs/glossary.md#packer)
