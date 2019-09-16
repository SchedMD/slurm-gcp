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

variable "machine_type" {
  description = "Compute Platform machine type to use in login node creation"
  default     = "n1-standard-2"
}

variable "node_count" {
  description = "The number of cluster login nodes to create"
  default     = 1
}

variable "labels" {
  description = "Labels to add to login instances (list of key value pairs)"
  default     = {}
}

variable "boot_disk_type" {
  description = "Type of boot disk to create for the cluster login node"
  default     = "pd-ssd"
}

variable "boot_disk_size" {
  description = "Size of boot disk to create for the cluster login node"
  default     = 16
}

variable "nfs_apps_server" {
  description = "IP address of the NFS server hosting the apps directory"
  default     = ""
}

variable "nfs_home_server" {
  description = "IP address of the NFS server hosting the home directory"
  default     = ""
}

variable "vpc_net" {
  description = "Name of the pre-defined VPC network where nodes will be attached"
  default     = ""
}

variable "vcp_subnet" {
  description = "Name of the pre-defined VPC subnet where nodes will be attached"
  default     = ""
}
