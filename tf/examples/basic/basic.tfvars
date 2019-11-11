cluster_name = "g1"
project      = "<project>"
zone         = "us-west1-b"
partitions = [
  { name                 = "debug"
    machine_type         = "n1-standard-2"
    max_node_count       = 10
    zone                 = "us-west1-a"
    compute_disk_type    = "pd-standard"
    compute_disk_size_gb = 50
    compute_labels       = []
    cpu_platform         = ""
    gpu_type             = ""
    gpu_count            = 0
    network_storage      = []
    preemptible_bursting = true
    static_node_count    = 2
  },
  { name                 = "partition2"
    machine_type         = "n1-standard-4"
    max_node_count       = 20
    zone                 = "us-west1-b"
    compute_disk_type    = "pd-standard"
    compute_disk_size_gb = 50
    compute_labels       = []
    cpu_platform         = ""
    gpu_type             = ""
    gpu_count            = 0
    network_storage      = []
    preemptible_bursting = false
    static_node_count    = 0
  }
]

#shared_vpc_host_project = "<vpc host project>"
