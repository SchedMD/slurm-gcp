# Using TPUs with Slurm GCP

This is not as straightforward as typical Slurm GCP because you are not able to
customize the image used by the TPU VM instances. So, we have to make Slurm
binaries available from an external mount. You can use the Slurm GCP image
foundry to install Slurm to just such an external mount.
```
# foundry/images.yaml
  images:
    - base: ubuntu-2004
      base_image: projects/ubuntu-os-cloud/global/images/family/ubuntu-2004-lts
      metadata:
        external-slurm-install: |
          remote: external-slurm-master-install
          mount: /opt/slurm
          type: gcsfuse
```

Currently, the TPU VM instances run Ubuntu 20.04, so that is the base on which
we will use foundry to compile Slurm. There is a script
(`foundry/custom.d/external_install_slurm.py`) that will compile and install
slurm to the external mount location in the metadata. I use a GCS bucket here,
but it could alternatively be an NFS mount. The process of creating preparing
this image and installing Slurm to the external mount could take as much as 40
minutes.

```
cd foundry
pipenv run ./foundry.py slurm-image-foundry --pause
```
`--pause` causes foundry not to actually make the image. We don't need it; we
only want the binaries.

Add the TPU partition to the partitions array in the tfvars file.
```
  { name                 = "v2_32_v2_alpha"
    machine_type         = "n1-356-96-tpu"
    static_node_count    = 0
    max_node_count       = 10
    zone                 = "europe-west4-a"
    image                = null
    image_hyperthreads   = true
    compute_disk_type    = "pd-standard"
    compute_disk_size_gb = 20
    compute_labels       = {}
    cpu_platform         = null
    gpu_count            = 0
    gpu_type             = null
    network_storage      = [{
      server_ip     = "none"
      remote_mount  = "external-slurm-install"
      local_mount   = "/opt/slurm"
      fs_type       = "gcsfuse"
      mount_options = "file_mode=775,dir_mode=775,allow_other"
    }]
    preemptible_bursting = false
    vpc_subnet           = "default"
    exclusive            = true
    enable_placement     = false
    regional_capacity    = false
    regional_policy      = {}
    instance_template    = null
    tpu_type             = "v2-32"
    tpu_version          = "v2-alpha"
  },
```

`image` is ignored since the tpu instance uses its own. There should not be any
static nodes in this partition; it won't work.  
The network_storage section is important; it should have the same path as where
the slurm binaries were installed to.  
The partition is not strictly required to be `exclusive`, but it
is preferred. That way the TPU is allocated and torn down for each job.

This will make a job and put you on the TPU VM:
`salloc -N1 -p <TPU partition name>`
