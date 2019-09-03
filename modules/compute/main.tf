resource "google_compute_instance" "compute_node" {
  name         = "${var.cluster_name}-compute-image-${format("%05d", var.partition_id)}"
  machine_type = var.compute_machine_type
  zone         = var.zone

  tags = ["compute"]

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
      type  = var.login_boot_disk_type
      size  = var.login_boot_disk_size
    }
  }

  network_interface {
    access_config {
    }

    subnetwork = var.network
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"

    startup-script = <<STARTUP
${templatefile("${path.module}/startup-script.tmpl", {
cluster_name = "${var.cluster_name}", 
project = "${var.project}", 
zone = "${var.zone}", 
instance_type = "compute",
munge_key = "${var.munge_key}", 
slurm_version ="${var.slurm_version}", 
def_slurm_acct = "${var.default_account}", 
def_slurm_users = "${var.default_users}", 
external_compute_ips = "${var.external_compute_ips}", 
nfs_apps_server = "${var.nfs_apps_server}", 
nfs_home_server = "${var.nfs_home_server}", 
controller_secondary_disk = "${var.controller_secondary_disk}", 
suspend_time = "${var.suspend_time}", 
partitions = "${var.partitions}"
})}
STARTUP
  }
}
