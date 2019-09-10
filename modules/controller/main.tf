resource "null_resource" "machine_type_cores" {
    count = "${length(var.partitions)}"

    provisioner "local-exec" {
        command = "gcloud compute machine-types describe ${var.partitions[count.index].machine_type} --format=\"csv[no-heading](guestCpus)\" > ${data.template_file.cores.rendered}.${count.index}"
    }
}

resource "null_resource" "machine_type_memory" {
    count = "${length(var.partitions)}"

    provisioner "local-exec" {
        command = "gcloud compute machine-types describe ${var.partitions[count.index].machine_type} --format=\"csv[no-heading](memoryMb)\" > ${data.template_file.memory.rendered}.${count.index}"
    }
}

data "template_file" "compute_nodes" {
    depends_on = ["null_resource.machine_type_cores", "null_resource.machine_type_memory"]
    template   = "${file("${path.module}/partition.tmpl")}"
    count      = "${length(var.partitions)}"
    vars       = {
        cluster_name = var.cluster_name
        cores        = tonumber(trimspace("${data.local_file.cores[count.index].content}")) / 2
        memory       = tonumber(trimspace("${data.local_file.memory[count.index].content}")) - (400 + ((tonumber(trimspace("${data.local_file.memory[count.index].content}")) / 1024) * 30))
        name         = var.partitions[count.index].name
        is_default   = count.index == 0 ? "YES" : "NO"
        range_start  = format("%05d", count.index * 1000)
        range_end    = format("%05d", count.index * 1000 + var.partitions[count.index].max_node_count - 1)
    }
}

data "template_file" "cores" {
    template = "${path.module}/cores.txt"
}

data "template_file" "memory" {
    template = "${path.module}/memory.txt"
}

data "local_file" "cores" {
    count    = "${length(var.partitions)}"
    filename = "${data.template_file.cores.rendered}.${count.index}"
    depends_on = ["null_resource.machine_type_cores"]
}

data "local_file" "memory" {
    count    = "${length(var.partitions)}"
    filename = "${data.template_file.memory.rendered}.${count.index}"
    depends_on = ["null_resource.machine_type_memory"]
}

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
#     enable-oslogin = "TRUE"

#     startup-script = <<STARTUP
# ${templatefile("${path.module}/startup-script.tmpl", {
# cluster_name = "${var.cluster_name}", 
# project = "${var.project}", 
# zone = "${var.zone}", 
# instance_type = "controller",
# munge_key = "${var.munge_key}", 
# slurm_version ="${var.slurm_version}", 
# def_slurm_acct = "${var.default_account}", 
# def_slurm_users = "${var.default_users}", 
# external_compute_ips = "${var.external_compute_ips}", 
# nfs_apps_server = "${var.nfs_apps_server}", 
# nfs_home_server = "${var.nfs_home_server}", 
# controller_secondary_disk = "${var.controller_secondary_disk}", 
# suspend_time = "${var.suspend_time}", 
# partitions = "${var.partitions}"
# })}
# STARTUP
# 
#     startup-script-compute = <<COMPUTESTARTUP
# ${templatefile("${path.module}/startup-script.tmpl", {
# cluster_name = "${var.cluster_name}", 
# project = "${var.project}", 
# zone = "${var.zone}", 
# instance_type = "compute",
# munge_key = "${var.munge_key}", 
# slurm_version ="${var.slurm_version}", 
# def_slurm_acct = "${var.default_account}", 
# def_slurm_users = "${var.default_users}", 
# external_compute_ips = "${var.external_compute_ips}", 
# nfs_apps_server = "${var.nfs_apps_server}", 
# nfs_home_server = "${var.nfs_home_server}", 
# controller_secondary_disk = "${var.controller_secondary_disk}", 
# suspend_time = "${var.suspend_time}", 
# partitions = "${var.partitions}"
# })}
# COMPUTESTARTUP

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

  provisioner "remote-exec" {
    inline = [ 
      "sudo yum update -y",
      "[ ! -d /var/log/slurm ] && sudo mkdir /var/log/slurm",
      "[ ! -d /tmp/slurm ] && mkdir /tmp/slurm"
    ]
    connection {
      private_key = "${file("~/.ssh/google_compute_engine")}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "wkh"
    }
  }

  provisioner "file" {
    source      = "${path.module}/packages.txt"
    destination = "/tmp/slurm/packages.txt"
    connection {
      private_key = "${file("~/.ssh/google_compute_engine")}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "wkh"
    }
  }

  provisioner "remote-exec" {
    inline = [ 
      "sudo yum -y install $(cat /tmp/slurm/packages.txt)"
    ]
    connection {
      private_key = "${file("~/.ssh/google_compute_engine")}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "wkh"
    }
  }

  provisioner "file" {
    source      = "${path.module}/../shared/functions.sh"
    destination = "/tmp/slurm/functions.sh"
    connection {
      private_key = "${file("~/.ssh/google_compute_engine")}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "wkh"
    }
  }

  provisioner "file" {
    source      = "${path.module}/configure.sh"
    destination = "/tmp/slurm/configure.sh"
    connection {
      private_key = "${file("~/.ssh/google_compute_engine")}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "wkh"
    }
  }

  provisioner "file" {
    destination = "/tmp/slurm/slurm.conf"
    content     = "${templatefile("${path.module}/../tmpl/slurm.conf.tmpl",{
cluster_name=var.cluster_name,
control_machine="${var.cluster_name}-controller",
apps_dir="/apps",
suspend_time=var.suspend_time
compute_nodes="${join("", data.template_file.compute_nodes.*.rendered)}"
})}"
    connection {
      private_key = "${file("~/.ssh/google_compute_engine")}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "wkh"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /apps/slurm/src",
      "sudo chmod a+x /tmp/slurm/configure.sh",
      "(cd /tmp/slurm; sudo ./configure.sh ${var.slurm_version})"
    ]
    connection {
      private_key = "${file("~/.ssh/google_compute_engine")}"
      host = google_compute_instance.controller_node.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = "wkh"
    }
  }

}

output "controller_node_name" {
  value = google_compute_instance.controller_node.name
}
