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
    template   = "${file("${path.module}/computenodes.tmpl")}"
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
