resource "google_compute_instance" "controller_node" {
  name         = "${var.cluster_name}-controller"
  machine_type = var.controller_machine_type
  zone         = var.zone

  tags = ["controller"]

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
      type  = var.controller_boot_disk_type
      size  = var.controller_boot_disk_size
    }
  }

  // Local SSD disk
  scratch_disk {
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
instance_type = "controller",
munge_key = "${var.munge_key}", 
slurm_version ="${var.slurm_version}", 
def_slurm_acct = "${var.default_account}", 
def_slurm_users = "${var.default_users}", 
external_compute_ips = "${var.external_compute_ips}", 
nfs_apps_server = "${var.nfs_apps_server}", 
nfs_home_server = "${var.nfs_home_server}", 
controller_secondary_disk = "${var.controller_secondary_disk}", 
suspend_time = "${var.suspend_time}", 
partitions = "[]"
})}
STARTUP

    startup-script-compute = <<COMPUTESTARTUP
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
partitions = "[]"
})}
COMPUTESTARTUP

    slurm_resume = <<RESUME
${file("${path.module}/resume.py")}
RESUME

    slurm_suspend = <<SUSPEND
${file("${path.module}/suspend.py")}
SUSPEND

    slurm-gcp-sync = <<GCPSYNC
${file("${path.module}/slurm-gcp-sync.py")}
GCPSYNC

    custom-compute-install = <<CUSTOMCOMPUTE
${file("${path.module}/custom-compute-install")}
CUSTOMCOMPUTE

    custom-controller-install = <<CUSTOMCONTROLLER
${file("${path.module}/custom-controller-install")}
CUSTOMCONTROLLER
  }
}
