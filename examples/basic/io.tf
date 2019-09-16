variable "project" {}
variable "region" {}
variable "cluster_name" {}
#variable "default_users" {}

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

output "controller_nat_ips" {
  value = "${module.slurm_cluster_controller.instance_nat_ips}"
}
output "controller_network_ips" {
  value = "${module.slurm_cluster_controller.instance_network_ips}"
}
output "login_nat_ips" {
  value = "${module.slurm_cluster_login.instance_nat_ips}"
}
output "login_network_ips" {
  value = "${module.slurm_cluster_login.instance_network_ips}"
}
