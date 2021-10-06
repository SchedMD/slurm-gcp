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

## Terraform Module

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
Copyright 2021 SchedMD LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 3.80.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_compute_template"></a> [compute\_template](#module\_compute\_template) | ./modules/instance_template | n/a |
| <a name="module_controller_instance"></a> [controller\_instance](#module\_controller\_instance) | ./modules/compute_instance | n/a |
| <a name="module_controller_template"></a> [controller\_template](#module\_controller\_template) | ./modules/instance_template | n/a |
| <a name="module_login_instance"></a> [login\_instance](#module\_login\_instance) | ./modules/compute_instance | n/a |
| <a name="module_login_template"></a> [login\_template](#module\_login\_template) | ./modules/instance_template | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ./modules/network | n/a |

## Resources

| Name | Type |
|------|------|
| [google_compute_project_metadata_item.compute_metadata](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_project_metadata_item) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster name used for accounting and resource naming. | `string` | n/a | yes |
| <a name="input_compute_service_account"></a> [compute\_service\_account](#input\_compute\_service\_account) | Service account to attach to the instance. See https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#service_account. | <pre>object({<br>    email  = string      # description: The service account email to use. If null, then the default will be used.<br>    scopes = set(string) # description: Set of scopes for service account to operate under.<br>  })</pre> | <pre>{<br>  "email": null,<br>  "scopes": null<br>}</pre> | no |
| <a name="input_compute_templates"></a> [compute\_templates](#input\_compute\_templates) | Maps slurm compute template name to instance definition. | <pre>map(object({<br>    ### network ###<br>    subnet_name   = string       # description: The subnetwork name to associate the template with.<br>    subnet_region = string       # description: The subnetwork region to associate the template with.<br>    tags          = list(string) # description: List of network tags.<br><br>    ### template ###<br>    instance_template_project = string # description: The project where the instance template exists. If 'null', then 'project_id' will be used.<br>    instance_template         = string # description: The template, by name, to use. This will override/ignore all manual instance configuration options.<br><br>    ### instance ###<br>    machine_type     = string # description: Machine type to create (e.g. n1-standard-1).<br>    min_cpu_platform = string # description: Specifies a minimum CPU platform. Applicable values are the friendly names of CPU platforms, such as Intel Haswell or Intel Skylake. See the complete list: https://cloud.google.com/compute/docs/instances/specify-min-cpu-platform.<br>    gpu = object({<br>      type  = string # description: GPU type. See https://cloud.google.com/compute/docs/gpus more details<br>      count = number # description: Number of GPUs to attach.<br>    })<br>    shielded_instance_config = object({  # description: Configuration not used unless 'enable_shielded_vm' is 'true'. If 'null', then the default configuration will be assumed. See https://cloud.google.com/security/shielded-cloud/shielded-vm.<br>      enable_secure_boot          = bool # description: Enables Secure Boot on instance. See https://cloud.google.com/security/shielded-cloud/shielded-vm#secure-boot.<br>      enable_vtpm                 = bool # description: Enables Virtual Trusted Platform Module (vTPM) on instance. See https://cloud.google.com/security/shielded-cloud/shielded-vm#vtpm<br>      enable_integrity_monitoring = bool # description: Enables integrity monitoring on instance. See https://cloud.google.com/security/shielded-cloud/shielded-vm#integrity-monitoring.<br>    })<br>    enable_confidential_vm = bool # description: Whether to enable the Confidential VM configuration on the instance. Note that the instance image must support Confidential VMs. See https://cloud.google.com/compute/docs/images.<br>    enable_shielded_vm     = bool # description: Whether to enable the Shielded VM configuration on the instance. Note that the instance image must support Shielded VMs. See https://cloud.google.com/compute/docs/images.<br>    disable_smt            = bool # description: Whether to disable Simultaneous Multi-Threading (SMT) on instance.<br>    preemptible            = bool # description: Allow the instance to be preempted.<br><br>    ### source image ###<br>    source_image_project = string # description: Project where the source image comes from.<br>    source_image_family  = string # description: Source image family.<br>    source_image         = string # description: Source disk image.<br><br>    ### disk ###<br>    disk_type        = string      # description: Boot disk type, can be either 'pd-ssd', 'local-ssd', or 'pd-standard'.<br>    disk_size_gb     = number      # description: Boot disk size in GB.<br>    disk_labels      = map(string) # description: Labels to be assigned to boot disk, provided as a map.<br>    disk_auto_delete = bool        # description: Whether or not the boot disk should be auto-deleted. This defaults to true.<br>    additional_disks = list(object({<br>      disk_name    = string      # description: Name of the disk. When not provided, this defaults to the name of the instance.<br>      device_name  = string      # description: A unique device name that is reflected into the /dev/ tree of a Linux operating system running within the instance. If not specified, the server chooses a default device name to apply to this disk.<br>      auto_delete  = bool        # description: Whether or not the disk should be auto-deleted. This defaults to true.<br>      boot         = bool        # description: Whether or not the disk should be a boot disk.<br>      disk_size_gb = number      # description: Disk size in GB.<br>      disk_type    = string      # description: Disk type, can be either 'pd-ssd', 'local-ssd', or 'pd-standard'.<br>      disk_labels  = map(string) # description: Labels to be assigned to the disk, provided as a map.<br>    }))<br>  }))</pre> | `{}` | no |
| <a name="input_config"></a> [config](#input\_config) | General Cluster configuration. | <pre>object({<br>    cloudsql = object({<br>      server_ip = string # description: Address of the database server.<br>      user      = string # description: The user to access the database as.<br>      password  = string # description: The password, given the user, to access the given database. (sensitive)<br>      db_name   = string # description: The database to access.<br>    })<br>    jwt_key   = string # description: Specific JWT key to use accross the cluster.<br>    munge_key = string # description: Specific munge key to use accross the cluster.<br><br>    ### storage ###<br>    network_storage = list(object({ # description: mounted on all instances<br>      server_ip     = string        # description: Address of the storage server.<br>      remote_mount  = string        # description: The location in the remote instance filesystem to mount from.<br>      local_mount   = string        # description: The location on the instance filesystem to mount to.<br>      fs_type       = string        # description: Filesystem type (e.g. "nfs").<br>      mount_options = string        # description: Options to mount with.<br>    }))<br>    login_network_storage = list(object({ # description: mounted on login and controller instances<br>      server_ip     = string              # description: Address of the storage server.<br>      remote_mount  = string              # description: The location in the remote instance filesystem to mount from.<br>      local_mount   = string              # description: The location on the instance filesystem to mount to.<br>      fs_type       = string              # description: Filesystem type (e.g. "nfs").<br>      mount_options = string              # description: Options to mount with.<br>    }))<br><br>    ### slurm conf files ###<br>    cgroup_conf_tpl   = string # description: path to file 'cgroup.conf.tpl'<br>    slurm_conf_tpl    = string # description: path to file 'slurm.conf.tpl'<br>    slurmdbd_conf_tpl = string # description: path to file 'slurmdbd.conf.tpl'<br><br>    ### scripts.d ###<br>    controller_d = string # description: path to controller scripts directory (e.g. controller.d). Runs controller type nodes.<br>    compute_d    = string # description: path to compute scripts directory (e.g. compute.d). Runs on compute, login, and controller type nodes.<br>  })</pre> | <pre>{<br>  "cgroup_conf_tpl": null,<br>  "cloudsql": null,<br>  "compute_d": null,<br>  "controller_d": null,<br>  "jwt_key": null,<br>  "login_network_storage": null,<br>  "munge_key": null,<br>  "network_storage": null,<br>  "slurm_conf_tpl": null,<br>  "slurmdbd_conf_tpl": null<br>}</pre> | no |
| <a name="input_controller_instances"></a> [controller\_instances](#input\_controller\_instances) | Instantiates controller node(s) from slurm 'controller\_template'. | <pre>list(object({<br>    template      = string # description: The controller template, by key, from 'controller_templates'.<br>    count_static  = number # description: Number of static nodes.<br>    subnet_name   = string # description: The subnetwork name to create instance in.<br>    subnet_region = string # description: The subnetwork region to create instance in.<br>  }))</pre> | `[]` | no |
| <a name="input_controller_service_account"></a> [controller\_service\_account](#input\_controller\_service\_account) | Service account to attach to the instance. See https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#service_account. | <pre>object({<br>    email  = string      # description: The service account email to use. If 'null' or 'default', then the default email will be used.<br>    scopes = set(string) # description: Set of scopes for service account to operate under.<br>  })</pre> | <pre>{<br>  "email": null,<br>  "scopes": null<br>}</pre> | no |
| <a name="input_controller_templates"></a> [controller\_templates](#input\_controller\_templates) | Maps slurm controller template name to instance definition. | <pre>map(object({<br>    ### network ###<br>    subnet_name   = string       # description: The subnetwork name to associate the template with.<br>    subnet_region = string       # description: The subnetwork region to associate the template with.<br>    tags          = list(string) # description: List of network tags.<br><br>    ### template ###<br>    instance_template_project = string # description: The project where the instance template exists. If 'null', then 'project_id' will be used.<br>    instance_template         = string # description: The template, by name, to use. This will override/ignore all manual instance configuration options.<br><br>    ### instance ###<br>    machine_type     = string # description: Machine type to create (e.g. n1-standard-1).<br>    min_cpu_platform = string # description: Specifies a minimum CPU platform. Applicable values are the friendly names of CPU platforms, such as Intel Haswell or Intel Skylake. See the complete list: https://cloud.google.com/compute/docs/instances/specify-min-cpu-platform.<br>    gpu = object({<br>      type  = string # description: GPU type. See https://cloud.google.com/compute/docs/gpus more details<br>      count = number # description: Number of GPUs to attach.<br>    })<br>    shielded_instance_config = object({  # description: Configuration not used unless 'enable_shielded_vm' is 'true'. If 'null', then the default configuration will be assumed. See https://cloud.google.com/security/shielded-cloud/shielded-vm.<br>      enable_secure_boot          = bool # description: Enables Secure Boot on instance. See https://cloud.google.com/security/shielded-cloud/shielded-vm#secure-boot.<br>      enable_vtpm                 = bool # description: Enables Virtual Trusted Platform Module (vTPM) on instance. See https://cloud.google.com/security/shielded-cloud/shielded-vm#vtpm<br>      enable_integrity_monitoring = bool # description: Enables integrity monitoring on instance. See https://cloud.google.com/security/shielded-cloud/shielded-vm#integrity-monitoring.<br>    })<br>    enable_confidential_vm = bool # description: Whether to enable the Confidential VM configuration on the instance. Note that the instance image must support Confidential VMs. See https://cloud.google.com/compute/docs/images.<br>    enable_shielded_vm     = bool # description: Whether to enable the Shielded VM configuration on the instance. Note that the instance image must support Shielded VMs. See https://cloud.google.com/compute/docs/images.<br>    disable_smt            = bool # description: Whether to disable Simultaneous Multi-Threading (SMT) on instance.<br>    preemptible            = bool # description: Allow the instance to be preempted.<br><br>    ### source image ###<br>    source_image_project = string # description: Project where the source image comes from.<br>    source_image_family  = string # description: Source image family.<br>    source_image         = string # description: Source disk image.<br><br>    ### disk ###<br>    disk_type        = string      # description: Boot disk type, can be either 'pd-ssd', 'local-ssd', or 'pd-standard'.<br>    disk_size_gb     = number      # description: Boot disk size in GB.<br>    disk_labels      = map(string) # description: Labels to be assigned to boot disk, provided as a map.<br>    disk_auto_delete = bool        # description: Whether or not the boot disk should be auto-deleted. This defaults to true.<br>    additional_disks = list(object({<br>      disk_name    = string      # description: Name of the disk. When not provided, this defaults to the name of the instance.<br>      device_name  = string      # description: A unique device name that is reflected into the /dev/ tree of a Linux operating system running within the instance. If not specified, the server chooses a default device name to apply to this disk.<br>      auto_delete  = bool        # description: Whether or not the disk should be auto-deleted. This defaults to true.<br>      boot         = bool        # description: Whether or not the disk should be a boot disk.<br>      disk_size_gb = number      # description: Disk size in GB.<br>      disk_type    = string      # description: Disk type, can be either 'pd-ssd', 'local-ssd', or 'pd-standard'.<br>      disk_labels  = map(string) # description: Labels to be assigned to the disk, provided as a map.<br>    }))<br>  }))</pre> | `{}` | no |
| <a name="input_enable_devel"></a> [enable\_devel](#input\_enable\_devel) | Enables development process for faster iterations. NOTE: *NOT* intended for production use. | `bool` | `false` | no |
| <a name="input_login_instances"></a> [login\_instances](#input\_login\_instances) | Instantiates login node(s) from slurm 'login\_template'. | <pre>list(object({<br>    template      = string # description: The login template, by key, from 'login_templates'.<br>    count_static  = number # description: Number of static nodes.<br>    subnet_name   = string # description: The subnetwork name to create instance in.<br>    subnet_region = string # description: The subnetwork region to create instance in.<br>  }))</pre> | `[]` | no |
| <a name="input_login_service_account"></a> [login\_service\_account](#input\_login\_service\_account) | Service account to attach to the instance. See https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#service_account. | <pre>object({<br>    email  = string      # description: The service account email to use. If null, then the default will be used.<br>    scopes = set(string) # description: Set of scopes for service account to operate under.<br>  })</pre> | <pre>{<br>  "email": null,<br>  "scopes": null<br>}</pre> | no |
| <a name="input_login_templates"></a> [login\_templates](#input\_login\_templates) | Maps slurm login template name to instance definition. | <pre>map(object({<br>    ### network ###<br>    subnet_name   = string       # description: The subnetwork name to associate the template with.<br>    subnet_region = string       # description: The subnetwork region to associate the template with.<br>    tags          = list(string) # description: List of network tags.<br><br>    ### template ###<br>    instance_template_project = string # description: The project where the instance template exists. If 'null', then 'project_id' will be used.<br>    instance_template         = string # description: The template, by name, to use. This will override/ignore all manual instance configuration options.<br><br>    ### instance ###<br>    machine_type     = string # description: Machine type to create (e.g. n1-standard-1).<br>    min_cpu_platform = string # description: Specifies a minimum CPU platform. Applicable values are the friendly names of CPU platforms, such as Intel Haswell or Intel Skylake. See the complete list: https://cloud.google.com/compute/docs/instances/specify-min-cpu-platform.<br>    gpu = object({<br>      type  = string # description: GPU type. See https://cloud.google.com/compute/docs/gpus more details<br>      count = number # description: Number of GPUs to attach.<br>    })<br>    shielded_instance_config = object({  # description: Configuration not used unless 'enable_shielded_vm' is 'true'. If 'null', then the default configuration will be assumed. See https://cloud.google.com/security/shielded-cloud/shielded-vm.<br>      enable_secure_boot          = bool # description: Enables Secure Boot on instance. See https://cloud.google.com/security/shielded-cloud/shielded-vm#secure-boot.<br>      enable_vtpm                 = bool # description: Enables Virtual Trusted Platform Module (vTPM) on instance. See https://cloud.google.com/security/shielded-cloud/shielded-vm#vtpm<br>      enable_integrity_monitoring = bool # description: Enables integrity monitoring on instance. See https://cloud.google.com/security/shielded-cloud/shielded-vm#integrity-monitoring.<br>    })<br>    enable_confidential_vm = bool # description: Whether to enable the Confidential VM configuration on the instance. Note that the instance image must support Confidential VMs. See https://cloud.google.com/compute/docs/images.<br>    enable_shielded_vm     = bool # description: Whether to enable the Shielded VM configuration on the instance. Note that the instance image must support Shielded VMs. See https://cloud.google.com/compute/docs/images.<br>    disable_smt            = bool # description: Whether to disable Simultaneous Multi-Threading (SMT) on instance.<br>    preemptible            = bool # description: Allow the instance to be preempted.<br><br>    ### source image ###<br>    source_image_project = string # description: Project where the source image comes from.<br>    source_image_family  = string # description: Source image family.<br>    source_image         = string # description: Source disk image.<br><br>    ### disk ###<br>    disk_type        = string      # description: Boot disk type, can be either 'pd-ssd', 'local-ssd', or 'pd-standard'.<br>    disk_size_gb     = number      # description: Boot disk size in GB.<br>    disk_labels      = map(string) # description: Labels to be assigned to boot disk, provided as a map.<br>    disk_auto_delete = bool        # description: Whether or not the boot disk should be auto-deleted. This defaults to true.<br>    additional_disks = list(object({<br>      disk_name    = string      # description: Name of the disk. When not provided, this defaults to the name of the instance.<br>      device_name  = string      # description: A unique device name that is reflected into the /dev/ tree of a Linux operating system running within the instance. If not specified, the server chooses a default device name to apply to this disk.<br>      auto_delete  = bool        # description: Whether or not the disk should be auto-deleted. This defaults to true.<br>      boot         = bool        # description: Whether or not the disk should be a boot disk.<br>      disk_size_gb = number      # description: Disk size in GB.<br>      disk_type    = string      # description: Disk type, can be either 'pd-ssd', 'local-ssd', or 'pd-standard'.<br>      disk_labels  = map(string) # description: Labels to be assigned to the disk, provided as a map.<br>    }))<br>  }))</pre> | `{}` | no |
| <a name="input_network"></a> [network](#input\_network) | Network configuration for cluster. | <pre>object({<br>    ### attach ###<br>    subnetwork_project = string # description: The project where the network and subnetworks exists. If 'null', then 'project_id' is used.<br>    network            = string # description: The name of the network to attach slurm resources to. If not 'null', then no VPC will be generated.<br><br>    ### generate ###<br>    auto_create_subnetworks = bool # description: Enables auto-generation of subnetworks in network when creating vpc and subnets. If 'true' this will override/ignore 'subnets_spec'.<br>    subnets_spec = list(object({<br>      cidr   = string # description: The cidr range of the subnetwork to create.<br>      region = string # description: The region of the subnetwork to create.<br>    }))<br>  })</pre> | <pre>{<br>  "auto_create_subnetworks": true,<br>  "network": null,<br>  "subnets_spec": null,<br>  "subnetwork_project": null<br>}</pre> | no |
| <a name="input_partitions"></a> [partitions](#input\_partitions) | Cluster partition configuration. | <pre>map(object({<br>    nodes = list(object({<br>      template      = string # description: The compute template, by key, from 'compute_templates'.<br>      count_static  = number # description: Number of static nodes. These nodes are exempt from SuspendProgram and ResumeProgram.<br>      count_dynamic = number # description: Number of dynamic nodes. These nodes are subject to SuspendProgram and ResumeProgram.<br>      subnet_name   = string # description: The subnetwork name to create instance in.<br>      subnet_region = string # description: The subnetwork region to create instance in.<br>    }))<br>    conf = map(string) # description: Partition configuration map.<br>  }))</pre> | `{}` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID to create resources in. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Cluster name |
| <a name="output_compute_template"></a> [compute\_template](#output\_compute\_template) | Compute template details |
| <a name="output_config"></a> [config](#output\_config) | Cluster configuration details |
| <a name="output_controller_template"></a> [controller\_template](#output\_controller\_template) | Controller template details |
| <a name="output_login_template"></a> [login\_template](#output\_login\_template) | Login template details |
| <a name="output_partitions"></a> [partitions](#output\_partitions) | Partition Configuration details |
| <a name="output_vpc"></a> [vpc](#output\_vpc) | vpc details |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
