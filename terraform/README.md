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
    $ cp example.tfvars my_example.tfvars
    $ vim my_example.tfvars
    $ terraform init
    $ terraform apply -var-file=my_example.tfvars
    $ terraform destroy
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

    Additionally, please go to [examples/](./examples) for examples on how to
    use the root module.
