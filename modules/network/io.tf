variable "region" {
  description = "Compute Platform region where the notebook server will be located"
  default     = "us-central1"
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

output "cluster_subnet_self_link" {
  value = google_compute_subnetwork.cluster_subnet.self_link
}

output "cluster_subnet_name" {
  value = google_compute_subnetwork.cluster_subnet.name
}
