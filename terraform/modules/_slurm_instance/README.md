# Module: Slurm Instance

This module creates a compute instance from instance template for a Slurm
cluster. Certain properties of the given instance template are set before being
deployed. Conflicting properties will be overwritten to ensure a useable cluster.

**Warning**: The source image is not modified. Make sure to use a compatible
source image.

**NOTE:** This module is only intended to be used by Slurm modules. For general usage,
please consider using `terraform-google-modules/vm/google//modules/compute_instance`
directly instead.
