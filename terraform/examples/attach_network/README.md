# Example: attach_network

In this example, it will attach a slurm cluster to an existing network. For
simplicity, we will attach to the `default` network as it exist by default
with auto-generated subnetworks.

Steps:

1. Initialze

    ```sh
    $ terrafrom init
    ```

    Initialize a new or existing Terraform working directory by creating
    initial files, loading any remote state, downloading modules, etc.

2. Plan (Optional)

    ```sh
    $ terraform plan
    ```

    Generates a speculative execution plan, showing what actions Terraform
    would take to apply the current configuration. This command will not
    actually perform the planned actions.

3. Create Infrastructure

    ```sh
    $ terraform apply
    ```

    Creates or updates infrastructure according to Terraform configuration
    files in the current directory.

4. Destroy Infrastructure

    ```sh
    $ terraform destroy
    ```

    Destroy Terraform-managed infrastructure.
