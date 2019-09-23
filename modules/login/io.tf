variable "network" {
  description = "Compute Platform network the notebook server will be connected to"
  default     = "default"
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

variable "deploy_user" {
  default     = "slurm_deployer"
}

variable "deploy_key_path" {
  default = "~/.ssh/google_compute_engine"
}

output "instance_nat_ips" {
  value = [ "${google_compute_instance.login_node.*.network_interface.0.access_config.0.nat_ip}" ]
}

output "instance_network_ips" {
  value = [ "${google_compute_instance.login_node.*.network_interface.0.network_ip}" ]
}
