# Overview

This example deploys a Slurm cluster in GCP with the [Singularity container runtime](https://sylabs.io/singularity/) installed.
An environment module for the installed version of Singularity is created so that cluster users can use it interactively, in their
shell, or in their batch jobs.

# Configuration

## tf/examples/singularity/basic.tfvars

Supply values for
- cluster_name: the name of cluster you will deploy to GCP
- project: the GCP project that will host your cluster resources
- zone: the GCP zone where your cluster resources will be deployed
- partitions: information about the Slurm partitions your cluster makes available to cluster users

## tf/examples/singularity/custom-controller-install

Supply values for
- GOLANG_VERSION: the [latest release](https://golang.org/) available is recommended
- SINGULARITY_VERSION: the [lastest release](https://github.com/hpcng/singularity/releases) is recommended

# Deployment

```terraform init```  
```make apply```

# Teardown

```make destroy```
