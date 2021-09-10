# slurm-gcp Terraform Modules

This module makes it easy to set up a new Slurm HPC cluster in GCP.

## Compatibility

This module uses several
[Google Cloud Foundataion Toolkit](https://cloud.google.com/foundation-toolkit)
modules and thus is contrained by their compatibility.

For simplicity, this module is meant for use with `Terraform ~> 1.0`.

## Usage

There are two ways to use this module:

* Inplace

    Copy [example.tfvars](example.tfvars) and fill out with required information.

    ```sh
    $ cp example.tfvars vars.tfvars
    $ vim vars.tfvars
    $ terraform init
    $ terraform apply -var-file=vars.tfvars
    ```

* Module (recommended)

    This module can be used dirtectly in your own `main.tf` file by adding the
    following:

    ```hcl
    module "slurm_cluster" {
      source = "./slurm-gcp/terraform"

      /* omitted for brevity */
    }
    ```

    **NOTE:** This is not a hosted module, hence source must be the path to the
    directory on filesystem.

    Additionally, please go to [examples/](examples/) for examples on how to
    use the root module.

### Destroy Resources

Clean-up terraform managed resources.

```sh
# Destroy compute nodes that have not been powered down by the slurm controller
$ CLUSTER_NAME=$(terraform output cluster_name)
$ ../scripts/destroy_nodes.py ${CLUSTER_NAME}

# Destroy terraform managed pieces of the slurm cluster
$ terraform destroy -var-file=vars.tfvars
```

**NOTE:** If the VPC/network is managed by terraform, then all resources that
are not managed by terraform (compute nodes, non-slurm instances) and on said
VPC/network must be terminated before the VPC/network can be destroyed. This
may require manual termination of resources. This includes bursted instances
that Slurm has not yet suspended. Failure to do so may lead to errors when
using `terraform destroy`.

**NOTE:** Compute node instances are not managed by terraform, rather by the
controller instance via scripts. Ergo, if the controller is destroyed
before all compute node instances are terminated, the cloud administrator
must manually handle the termination of orpahned compute node instances.
Failure to manually moderate resources may lead to additional cloud costs.

A convienance script, [`destroy_nodes.py`](../scripts/destroy_nodes.py), is
provided to assist with node cleanup. Although it can be ran at any time, it is
suggested to run this before `terraform destroy` would be run.
