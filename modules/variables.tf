variable "project" {
  description = "Cloud Platform project that hosts the notebook server(s)"
}

variable "network" {
  description = "Compute Platform network the notebook server will be connected to"
  default     = "default"
}

variable "region" {
  description = "Compute Platform region where the notebook server will be located"
  default     = "us-central1"
}

variable "zone" {
  description = "Compute Platform zone where the notebook server will be located"
  default     = "us-central1-b"
}

variable "cluster_name" {
  description = "Name of the Slurm cluster"
}

variable "accelerator_type" {
  description = "GPU type to attach to the node"
  default     = "nvidia-tesla-v100"
}

variable "accelerator_count" {
  description = "The number of GPUs to attach to the node"
  default     = 0
}

variable "controller_machine_type" {
  description = "Compute Platform machine type to use in controller node creation"
  default     = "n1-standard-4"
}

variable "login_machine_type" {
  description = "Compute Platform machine type to use in login node creation"
  default     = "n1-standard-2"
}

variable "login_node_count" {
  description = "The number of cluster login nodes to create"
  default     = 1
}

variable "login_labels" {
  description = "Labels to add to login instances (list of key value pairs)"
  default     = {}
}

variable "cluster_network_cidr_range" {
  description = "CIDR range for cluster network"
  default     = "10.10.0.0/16"
}

variable "private_ip_google_access" {
  description = "Determines whether instances can access Google services w/o external addresses"
  default     = true
}

variable "controller_boot_disk_type" {
  description = "Type of boot disk to create for the cluster controller node"
  default     = "pd-ssd"
}

variable "controller_boot_disk_size" {
  description = "Size of boot disk to create for the cluster controller node"
  default     = 64
}

variable "login_boot_disk_type" {
  description = "Type of boot disk to create for the cluster login node"
  default     = "pd-ssd"
}

variable "login_boot_disk_size" {
  description = "Size of boot disk to create for the cluster login node"
  default     = 16
}

variable "controller_labels" {
  description = "Labels to add to controller node (a list of key value pairs)"
  default     = {}
}

variable "controller_secondary_disk" {
  description = "Boolean indicating whether or not to allocate a secondary disk on the controller node"
  default     = 0
}

variable "controller_secondary_disk_type" {
  description = "Type of secondary disk to create for the controller node"
  default     = "pd-ssd"
}

variable "controller_secondary_disk_size" {
  description = "Size of secondary disk to create for the controller node"
  default     = 128
}

variable "default_account" {
  description = "Default account to setup for accounting"
  default     = "default"
}

variable "default_users" {
  description = "Default users to add to the account database (added to default_account)"
  default     = []
}

variable "external_compute_ips" {
  description = "Boolean indicating whether or not compute nodes are assigned external IPs"
  default     = 0 
}

variable "munge_key" {
  description = "Specific munge key to use (e.g. date +%s | sha512sum | cut -d' ' -f1) generate a random key if none is specified"
  default     = ""
}

variable "nfs_apps_server" {
  description = "IP address of the NFS server hosting the apps directory"
  default     = ""
}

variable "nfs_home_server" {
  description = "IP address of the NFS server hosting the home directory"
  default     = ""
}

variable "shared_vpc_host_project" {
  description = "Shared VPC network this project has been granted access to; requires external IPs or Cloud NAT configured in the host project"
  default     = ""
}

variable "slurm_version" {
  description = "The Slurm version to install. The version should match the link name found at https://www.schedmd.com/downloads.php"
  default     = "18.08-latest"
}

variable "suspend_time" {
  description = "Idle time (in sec) to wait before nodes go away"
  default     = 300
}

variable "vpc_net" {
  description = "Name of the pre-defined VPC network where nodes will be attached"
  default     = ""
}

variable "vcp_subnet" {
  description = "Name of the pre-defined VPC subnet where nodes will be attached"
  default     = ""
}

variable "partitions" {
  description = "Array of partition specifications"
  default     = "[]"
}
