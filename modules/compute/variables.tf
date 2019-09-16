variable "project" {
  type        = string
  description = "Cloud Platform project that hosts the notebook server(s)"
}

variable "region" {
  type        = string
  description = "Compute Platform region where the notebook server will be located"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "Compute Platform zone where the notebook server will be located"
  default     = "us-central1-b"
}

variable "network" {
  type        = string
  description = "Compute Platform network the notebook server will be connected to"
  default     = "default"
}

variable "vpc_net" {
  type        = string
  description = "Name of the pre-defined VPC network where nodes will be attached"
  default     = ""
}

variable "vcp_subnet" {
  type        = string
  description = "Name of the pre-defined VPC subnet where nodes will be attached"
  default     = ""
}

variable "cluster_network_cidr_range" {
  type        = string
  description = "CIDR range for cluster network"
  default     = "10.10.0.0/16"
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

variable "private_ip_google_access" {
  type        = number
  description = "Determines whether instances can access Google services w/o external addresses"
  default     = 1
}

variable "external_compute_ips" {
  type        = number
  description = "Boolean indicating whether or not compute nodes are assigned external IPs"
  default     = 0 
}

variable "cluster_name" {
  type        = string
  description = "Name of the Slurm cluster"
}

variable "machine_type" {
  description = "Compute Platform machine type to use in compute node creation"
  default     = "n1-standard-4"
}

variable "labels" {
  type        = map(string)
  description = "Labels to add to login instances (list of key value pairs)"
  default     = {}
}

variable "boot_disk_type" {
  type        = string
  description = "Type of boot disk to create for the cluster compute nodes"
  default     = "pd-ssd"
}

variable "boot_disk_size" {
  type        = number
  description = "Size of boot disk to create for the cluster compute nodes"
  default     = 64
}

variable "accelerator_type" {
  description = "GPU type to attach to the node"
  default     = "nvidia-tesla-v100"
}

variable "accelerator_count" {
  type        = number
  description = "The number of GPUs to attach to the node"
  default     = 0
}

variable "controller_secondary_disk" {
  description = "Boolean indicating whether or not to allocate a secondary disk on the controller node"
  default     = 0
}

variable "default_account" {
  type        = string
  description = "Default account to setup for accounting"
  default     = "default"
}

variable "default_users" {
  type        = string
  description = "Default users to add to the account database (added to default_account)"
}

variable "munge_key" {
  description = "Specific munge key to use (e.g. date +%s | sha512sum | cut -d' ' -f1) generate a random key if none is specified"
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
