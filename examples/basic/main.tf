provider "google" {
  project = var.project
  region  = var.region
}

module "slurm_cluster_network" {
  source = "../../modules/network"

  cluster_name = var.cluster_name
  project      = var.project
}

module "slurm_cluster_controller" {
  source = "../../modules/controller"

  cluster_name  = var.cluster_name
  network       = module.slurm_cluster_network.cluster_subnet_self_link
  project       = var.project
  default_users = var.default_users
}

module "slurm_cluster_login" {
  source = "../../modules/login"

  cluster_name      = var.cluster_name
  network           = module.slurm_cluster_network.cluster_subnet_self_link
  login_node_count  = 1
  project           = var.project
  default_users     = var.default_users
}
