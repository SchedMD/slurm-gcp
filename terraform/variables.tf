# Copyright 2021 SchedMD LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

###########
# GENERAL #
###########

variable "project_id" {
  type        = string
  description = "Project ID to create resources in."
}

variable "cluster_name" {
  type        = string
  description = "Cluster name used for accounting and resource naming."
}

variable "enable_devel" {
  type        = bool
  description = "Enables development process for faster iterations. NOTE: *NOT* intended for production use."
  default     = false
}

###########
# NETWORK #
###########

variable "network" {
  type = object({
    ### attach ###
    subnetwork_project = string // description: The project where the network and subnetworks exists. If 'null', then 'project_id' is used.
    network            = string // description: The name of the network to identify as available to attach slurm resources to.
    subnets = list(object({
      name   = string // description: The name of the subnetwork to identify as available to attach slurm resources to.
      region = string // description: The region of the subnetwork to identify as available to attach slurm resources to.
    }))

    ### generate ###
    auto_create_subnetworks = bool // description: Enables auto-generation of subnetworks in network when creating vpc and subnets. If 'true' this will override/ignore 'subnets_spec'.
    subnets_spec = list(object({
      cidr   = string // description: The cidr range of the subnetwork to create.
      region = string // description: The region of the subnetwork to create.
    }))
  })
  default = {
    auto_create_subnetworks = true
    network                 = null
    subnets                 = null
    subnets_spec            = null
    subnetwork_project      = null
  }
}

#################
# CONFIGURATION #
#################

variable "config" {
  ### setup ###
  type = object({
    cloudsql = object({
      server_ip = string // description: Address of the database server.
      user      = string // description: The user to access the database as.
      password  = string // description: The password, given the user, to access the given database. (sensitive)
      db_name   = string // description: The database to access.
    })
    jwt_key   = string // description: Specific JWT key to use accross the cluster.
    munge_key = string // description: Specific munge key to use accross the cluster.

    ### storage ###
    network_storage = list(object({ // description: mounted on all instances
      server_ip     = string        // description: Address of the storage server.
      remote_mount  = string        // description: The location in the remote instance filesystem to mount from.
      local_mount   = string        // description: The location on the instance filesystem to mount to.
      fs_type       = string        // description: Filesystem type (e.g. "nfs").
      mount_options = string        // description: Options to mount with.
    }))
    login_network_storage = list(object({ // description: mounted on login and controller instances
      server_ip     = string              // description: Address of the storage server.
      remote_mount  = string              // description: The location in the remote instance filesystem to mount from.
      local_mount   = string              // description: The location on the instance filesystem to mount to.
      fs_type       = string              // description: Filesystem type (e.g. "nfs").
      mount_options = string              // description: Options to mount with.
    }))

    ### slurm.conf ###
    suspend_time = number // description: Number of seconds a node may be idle or down before being placed into power save mode by SuspendProgram.
  })
  sensitive = true
  default = {
    cloudsql              = null
    jwt_key               = null
    login_network_storage = null
    munge_key             = null
    network_storage       = null
    suspend_time          = null
  }
}

##############
# CONTROLLER #
##############

variable "controller_templates" {
  type = map(object({
    ### network ###
    subnet_name   = string       // description: The subnetwork name to associate the template with.
    subnet_region = string       // description: The subnetwork region to associate the template with.
    tags          = list(string) // description: List of network tags.

    ### template ###
    instance_template_project = string // description: The project where the instance template exists. If 'null', then 'project_id' will be used.
    instance_template         = string // description: The template, by name, to use. This will override/ignore all manual instance configuration options.

    ### instance ###
    machine_type     = string // description: Machine type to create (e.g. n1-standard-1).
    min_cpu_platform = string // description: Specifies a minimum CPU platform. Applicable values are the friendly names of CPU platforms, such as Intel Haswell or Intel Skylake. See the complete list: https://cloud.google.com/compute/docs/instances/specify-min-cpu-platform.
    gpu = object({
      type  = string // description: GPU type. See https://cloud.google.com/compute/docs/gpus more details
      count = number // description: Number of GPUs to attach.
    })
    service_account = object({ // description: Service account to attach to the instance. See https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#service_account. If 'null', then the 'default' account will be used.
      email  = string          // description: The service account email to use.
      scopes = set(string)     // description: Set of scopes for service account to operate under.
    })
    shielded_instance_config = object({  // description: Configuration not used unless 'enable_shielded_vm' is 'true'. If 'null', then the default configuration will be assumed. See https://cloud.google.com/security/shielded-cloud/shielded-vm.
      enable_secure_boot          = bool // description: Enables Secure Boot on instance. See https://cloud.google.com/security/shielded-cloud/shielded-vm#secure-boot.
      enable_vtpm                 = bool // description: Enables Virtual Trusted Platform Module (vTPM) on instance. See https://cloud.google.com/security/shielded-cloud/shielded-vm#vtpm
      enable_integrity_monitoring = bool // description: Enables integrity monitoring on instance. See https://cloud.google.com/security/shielded-cloud/shielded-vm#integrity-monitoring.
    })
    enable_confidential_vm = bool // description: Whether to enable the Confidential VM configuration on the instance. Note that the instance image must support Confidential VMs. See https://cloud.google.com/compute/docs/images.
    enable_shielded_vm     = bool // description: Whether to enable the Shielded VM configuration on the instance. Note that the instance image must support Shielded VMs. See https://cloud.google.com/compute/docs/images.
    disable_smt            = bool // description: Whether to disable Simultaneous Multi-Threading (SMT) on instance.
    preemptible            = bool // description: Allow the instance to be preempted.

    ### source image ###
    source_image_project = string // description: Project where the source image comes from.
    source_image_family  = string // description: Source image family.
    source_image         = string // description: Source disk image.

    ### disk ###
    disk_type        = string      // description: Boot disk type, can be either 'pd-ssd', 'local-ssd', or 'pd-standard'.
    disk_size_gb     = number      // description: Boot disk size in GB.
    disk_labels      = map(string) // description: Labels to be assigned to boot disk, provided as a map.
    disk_auto_delete = bool        // description: Whether or not the boot disk should be auto-deleted. This defaults to true.
    additional_disks = list(object({
      disk_name    = string      // description: Name of the disk. When not provided, this defaults to the name of the instance.
      device_name  = string      // description: A unique device name that is reflected into the /dev/ tree of a Linux operating system running within the instance. If not specified, the server chooses a default device name to apply to this disk.
      auto_delete  = bool        // description: Whether or not the disk should be auto-deleted. This defaults to true.
      boot         = bool        // description: Whether or not the disk should be a boot disk.
      disk_size_gb = number      // description: Disk size in GB.
      disk_type    = string      // description: Disk type, can be either 'pd-ssd', 'local-ssd', or 'pd-standard'.
      disk_labels  = map(string) // description: Labels to be assigned to the disk, provided as a map.
    }))
  }))
  default = {}
}

variable "controller_instances" {
  type = list(object({
    template      = string // description: The controller template, by key, from 'controller_templates'.
    count_static  = number // description: Number of static nodes.
    subnet_name   = string // description: The subnetwork name to create instance in.
    subnet_region = string // description: The subnetwork region to create instance in.
  }))
  default = []
}

#########
# LOGIN #
#########

variable "login_templates" {
  type = map(object({
    ### network ###
    subnet_name   = string       // description: The subnetwork name to associate the template with.
    subnet_region = string       // description: The subnetwork region to associate the template with.
    tags          = list(string) // description: List of network tags.

    ### template ###
    instance_template_project = string // description: The project where the instance template exists. If 'null', then 'project_id' will be used.
    instance_template         = string // description: The template, by name, to use. This will override/ignore all manual instance configuration options.

    ### instance ###
    machine_type     = string // description: Machine type to create (e.g. n1-standard-1).
    min_cpu_platform = string // description: Specifies a minimum CPU platform. Applicable values are the friendly names of CPU platforms, such as Intel Haswell or Intel Skylake. See the complete list: https://cloud.google.com/compute/docs/instances/specify-min-cpu-platform.
    gpu = object({
      type  = string // description: GPU type. See https://cloud.google.com/compute/docs/gpus more details
      count = number // description: Number of GPUs to attach.
    })
    service_account = object({ // description: Service account to attach to the instance. See https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#service_account. If 'null', then the 'default' account will be used.
      email  = string          // description: The service account email to use.
      scopes = set(string)     // description: Set of scopes for service account to operate under.
    })
    shielded_instance_config = object({  // description: Configuration not used unless 'enable_shielded_vm' is 'true'. If 'null', then the default configuration will be assumed. See https://cloud.google.com/security/shielded-cloud/shielded-vm.
      enable_secure_boot          = bool // description: Enables Secure Boot on instance. See https://cloud.google.com/security/shielded-cloud/shielded-vm#secure-boot.
      enable_vtpm                 = bool // description: Enables Virtual Trusted Platform Module (vTPM) on instance. See https://cloud.google.com/security/shielded-cloud/shielded-vm#vtpm
      enable_integrity_monitoring = bool // description: Enables integrity monitoring on instance. See https://cloud.google.com/security/shielded-cloud/shielded-vm#integrity-monitoring.
    })
    enable_confidential_vm = bool // description: Whether to enable the Confidential VM configuration on the instance. Note that the instance image must support Confidential VMs. See https://cloud.google.com/compute/docs/images.
    enable_shielded_vm     = bool // description: Whether to enable the Shielded VM configuration on the instance. Note that the instance image must support Shielded VMs. See https://cloud.google.com/compute/docs/images.
    disable_smt            = bool // description: Whether to disable Simultaneous Multi-Threading (SMT) on instance.
    preemptible            = bool // description: Allow the instance to be preempted.

    ### source image ###
    source_image_project = string // description: Project where the source image comes from.
    source_image_family  = string // description: Source image family.
    source_image         = string // description: Source disk image.

    ### disk ###
    disk_type        = string      // description: Boot disk type, can be either 'pd-ssd', 'local-ssd', or 'pd-standard'.
    disk_size_gb     = number      // description: Boot disk size in GB.
    disk_labels      = map(string) // description: Labels to be assigned to boot disk, provided as a map.
    disk_auto_delete = bool        // description: Whether or not the boot disk should be auto-deleted. This defaults to true.
    additional_disks = list(object({
      disk_name    = string      // description: Name of the disk. When not provided, this defaults to the name of the instance.
      device_name  = string      // description: A unique device name that is reflected into the /dev/ tree of a Linux operating system running within the instance. If not specified, the server chooses a default device name to apply to this disk.
      auto_delete  = bool        // description: Whether or not the disk should be auto-deleted. This defaults to true.
      boot         = bool        // description: Whether or not the disk should be a boot disk.
      disk_size_gb = number      // description: Disk size in GB.
      disk_type    = string      // description: Disk type, can be either 'pd-ssd', 'local-ssd', or 'pd-standard'.
      disk_labels  = map(string) // description: Labels to be assigned to the disk, provided as a map.
    }))
  }))
  default = {}
}

variable "login_instances" {
  type = list(object({
    template      = string // description: The login template, by key, from 'login_templates'.
    count_static  = number // description: Number of static nodes.
    subnet_name   = string // description: The subnetwork name to create instance in.
    subnet_region = string // description: The subnetwork region to create instance in.
  }))
  default = []
}

###########
# COMPUTE #
###########

variable "compute_templates" {
  type = map(object({
    ### network ###
    subnet_name   = string       // description: The subnetwork name to associate the template with.
    subnet_region = string       // description: The subnetwork region to associate the template with.
    tags          = list(string) // description: List of network tags.

    ### template ###
    instance_template_project = string // description: The project where the instance template exists. If 'null', then 'project_id' will be used.
    instance_template         = string // description: The template, by name, to use. This will override/ignore all manual instance configuration options.

    ### instance ###
    machine_type     = string // description: Machine type to create (e.g. n1-standard-1).
    min_cpu_platform = string // description: Specifies a minimum CPU platform. Applicable values are the friendly names of CPU platforms, such as Intel Haswell or Intel Skylake. See the complete list: https://cloud.google.com/compute/docs/instances/specify-min-cpu-platform.
    gpu = object({
      type  = string // description: GPU type. See https://cloud.google.com/compute/docs/gpus more details
      count = number // description: Number of GPUs to attach.
    })
    service_account = object({ // description: Service account to attach to the instance. See https://www.terraform.io/docs/providers/google/r/compute_instance_template.html#service_account. If 'null', then the 'default' account will be used.
      email  = string          // description: The service account email to use.
      scopes = set(string)     // description: Set of scopes for service account to operate under.
    })
    shielded_instance_config = object({  // description: Configuration not used unless 'enable_shielded_vm' is 'true'. If 'null', then the default configuration will be assumed. See https://cloud.google.com/security/shielded-cloud/shielded-vm.
      enable_secure_boot          = bool // description: Enables Secure Boot on instance. See https://cloud.google.com/security/shielded-cloud/shielded-vm#secure-boot.
      enable_vtpm                 = bool // description: Enables Virtual Trusted Platform Module (vTPM) on instance. See https://cloud.google.com/security/shielded-cloud/shielded-vm#vtpm
      enable_integrity_monitoring = bool // description: Enables integrity monitoring on instance. See https://cloud.google.com/security/shielded-cloud/shielded-vm#integrity-monitoring.
    })
    enable_confidential_vm = bool // description: Whether to enable the Confidential VM configuration on the instance. Note that the instance image must support Confidential VMs. See https://cloud.google.com/compute/docs/images.
    enable_shielded_vm     = bool // description: Whether to enable the Shielded VM configuration on the instance. Note that the instance image must support Shielded VMs. See https://cloud.google.com/compute/docs/images.
    disable_smt            = bool // description: Whether to disable Simultaneous Multi-Threading (SMT) on instance.
    preemptible            = bool // description: Allow the instance to be preempted.

    ### source image ###
    source_image_project = string // description: Project where the source image comes from.
    source_image_family  = string // description: Source image family.
    source_image         = string // description: Source disk image.

    ### disk ###
    disk_type        = string      // description: Boot disk type, can be either 'pd-ssd', 'local-ssd', or 'pd-standard'.
    disk_size_gb     = number      // description: Boot disk size in GB.
    disk_labels      = map(string) // description: Labels to be assigned to boot disk, provided as a map.
    disk_auto_delete = bool        // description: Whether or not the boot disk should be auto-deleted. This defaults to true.
    additional_disks = list(object({
      disk_name    = string      // description: Name of the disk. When not provided, this defaults to the name of the instance.
      device_name  = string      // description: A unique device name that is reflected into the /dev/ tree of a Linux operating system running within the instance. If not specified, the server chooses a default device name to apply to this disk.
      auto_delete  = bool        // description: Whether or not the disk should be auto-deleted. This defaults to true.
      boot         = bool        // description: Whether or not the disk should be a boot disk.
      disk_size_gb = number      // description: Disk size in GB.
      disk_type    = string      // description: Disk type, can be either 'pd-ssd', 'local-ssd', or 'pd-standard'.
      disk_labels  = map(string) // description: Labels to be assigned to the disk, provided as a map.
    }))
  }))
  default = {}
}

##############
# PARTITIONS #
##############

variable "partitions" {
  type = map(object({
    nodes = list(object({
      template      = string // description: The compute template, by key, from 'compute_templates'.
      count_static  = number // description: Number of static nodes. These nodes are exempt from SuspendProgram and ResumeProgram.
      count_dynamic = number // description: Number of dynamic nodes. These nodes are subject to SuspendProgram and ResumeProgram.
      subnet_name   = string // description: The subnetwork name to create instance in.
      subnet_region = string // description: The subnetwork region to create instance in.
    }))
    conf = map(string) // description: Partition configuration map.
  }))
  default = {}
}
