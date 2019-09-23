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

variable "controller_machine_type" {
  description = "Compute Platform machine type to use in controller node creation"
  default     = "n1-standard-4"
}

variable "controller_boot_disk_type" {
  description = "Type of boot disk to create for the cluster controller node"
  default     = "pd-ssd"
}

variable "controller_boot_disk_size" {
  description = "Size of boot disk to create for the cluster controller node"
  default     = 64
}

variable "slurm_version" {
  description = "The Slurm version to install. The version should match the link name found at https://www.schedmd.com/downloads.php"
  default     = "19.05.2"
}

variable "suspend_time" {
  description = "Idle time (in sec) to wait before nodes go away"
  default     = 300
}

variable "partitions" {
  type = list(object({
              name                 = string,
              machine_type         = string,
              max_node_count       = number,
              zone                 = string,
              compute_disk_type    = string,
              compute_disk_size_gb = number,
              compute_labels       = list(string),
              cpu_platform         = string,
              gpu_type             = string,
              gpu_count            = number,
              preemptible_bursting = number,
              static_node_count    = number}))
}

output "controller_node_name" {
  value = google_compute_instance.controller_node.name
}

output "instance_nat_ips" {
  value = [ "${google_compute_instance.controller_node.*.network_interface.0.access_config.0.nat_ip}" ]
}

output "instance_network_ips" {
  value = [ "${google_compute_instance.controller_node.*.network_interface.0.network_ip}" ]
}
