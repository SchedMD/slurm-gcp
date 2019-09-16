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

variable "cluster_network_cidr_range" {
  description = "CIDR range for cluster network"
  default     = "10.10.0.0/16"
}

variable "private_ip_google_access" {
  description = "Determines whether instances can access Google services w/o external addresses"
  default     = true
}
variable "external_compute_ips" {
  description = "Boolean indicating whether or not compute nodes are assigned external IPs"
  default     = 0 
}

variable "shared_vpc_host_project" {
  description = "Shared VPC network this project has been granted access to; requires external IPs or Cloud NAT configured in the host project"
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
