variable "cluster_name" {}
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

output "content" {
    value = "${templatefile("${path.module}/slurm.conf.tmpl",{
cluster_name=var.cluster_name,
control_machine="${var.cluster_name}-controller",
apps_dir="/apps",
suspend_time=300,
compute_nodes="${join("", data.template_file.compute_nodes.*.rendered)}"
})}"
}
