provider "google" {
  project = var.project
  region  = var.region
}

module "slurm_cluster_network" {
  source = "../../modules/network"

  cluster_name = var.cluster_name
  region  = var.region
}

module "slurm_cluster_controller" {
  source = "../../modules/controller"

  cluster_name  = var.cluster_name
  network       = module.slurm_cluster_network.cluster_subnet_self_link
  partitions    = var.partitions
}

module "slurm_cluster_login" {
  source = "../../modules/login"

  cluster_name      = var.cluster_name
  network           = module.slurm_cluster_network.cluster_subnet_self_link
  node_count        = 1
  nfs_apps_server   = module.slurm_cluster_controller.controller_node_name
}

# module "slurm_cluster_compute" {
#   source = "../../modules/compute"
# 
#   cluster_name  = var.cluster_name
#   network       = module.slurm_cluster_network.cluster_subnet_self_link
#   project       = var.project
#   default_users = var.default_users
#   partitions    = "${jsonencode(var.partitions)}"
#   partition_id  = 0
# }

