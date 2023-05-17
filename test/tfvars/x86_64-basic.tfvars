region = "us-central1"

enable_bigquery_load   = true
enable_cleanup_compute = true

create_bucket = false
bucket_name   = "slurm-test"

controller_instance_config = {
  disk_size_gb = 32
  disk_type    = "pd-ssd"
  machine_type = "n1-standard-8"
}

login_nodes = [
  {
    # Group Definition
    group_name = "frontend"

    # Template By Definition
    disk_size_gb = 32
    disk_type    = "pd-standard"
    machine_type = "n1-standard-1"
    service_account = {
      email  = "default"
      scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    }

    # Instance Definition
    num_instances = 1
  },
]

partitions = [
  {
    partition_name = "debug"
    partition_conf = {
      Default        = "YES"
      ResumeTimeout  = 300
      SuspendTimeout = 300
      SuspendTime    = 300
    }
    partition_nodes = [
      {
        # Group Definition
        group_name             = "n1"
        node_count_dynamic_max = 20
        node_count_static      = 1

        # Template By Definition
        disk_size_gb = 32
        disk_type    = "pd-standard"
        machine_type = "n1-standard-2"
        service_account = {
          email  = "default"
          scopes = ["https://www.googleapis.com/auth/cloud-platform"]
        }
      },
    ]
    # Options
    enable_job_exclusive    = false
    enable_placement_groups = false
  },
  {
    partition_name = "gpu"
    partition_conf = {
      ResumeTimeout  = 300
      SuspendTimeout = 300
      SuspendTime    = 300
    }
    partition_nodes = [
      {
        # Group Definition
        group_name             = "v100"
        node_count_dynamic_max = 10

        # Template By Definition
        disk_size_gb = 32
        disk_type    = "pd-standard"
        gpu = {
          count = 1
          type  = "nvidia-tesla-v100"
        }
        machine_type = "n1-standard-4"
        service_account = {
          email  = "default"
          scopes = ["https://www.googleapis.com/auth/cloud-platform"]
        }
      },
    ]
    # Options
    enable_job_exclusive    = false
    enable_placement_groups = false
  },
  {
    partition_name = "c2"
    partition_conf = {
      Default        = "YES"
      ResumeTimeout  = 300
      SuspendTimeout = 300
      SuspendTime    = 300
    }
    partition_nodes = [
      {
        # Group Definition
        group_name             = "s2"
        node_count_dynamic_max = 10
        node_count_static      = 0
        node_conf = {
          Features = "test"
        }

        # Template By Definition
        disk_size_gb = 32
        disk_type    = "pd-standard"
        machine_type = "c2-standard-4"
        service_account = {
          email  = "default"
          scopes = ["https://www.googleapis.com/auth/cloud-platform"]
        }
      },
    ]
    # Options
    enable_job_exclusive    = true
    enable_placement_groups = true
  },
  {
    partition_name = "spot"
    partition_conf = {
      ResumeTimeout  = 300
      SuspendTimeout = 300
      SuspendTime    = 300
    }
    partition_nodes = [
      {
        # Group Definition
        group_name             = "n1"
        node_count_dynamic_max = 10

        # Template By Definition
        disk_size_gb = 32
        disk_type    = "pd-standard"
        machine_type = "n1-standard-2"
        preemptible  = true
        service_account = {
          email = "default"
          scopes = [
            "https://www.googleapis.com/auth/cloud-platform",
          ]
        }

        # Instance Definition
        spot_instance_config = {
          termination_action = "STOP"
        }
      },
    ]
    # Options
    enable_job_exclusive    = false
    enable_placement_groups = false
  },
  {
    partition_name = "shgpu"
    partition_conf = {
      ResumeTimeout  = 300
      SuspendTimeout = 300
      SuspendTime    = 300
    }
    partition_nodes = [
      {
        # Group Definition
        group_name             = "v100"
        node_count_dynamic_max = 10

        # Template By Definition
        disk_size_gb       = 32
        disk_type          = "pd-standard"
        enable_shielded_vm = true
        gpu = {
          count = 1
          type  = "nvidia-tesla-v100"
        }
        machine_type = "n1-standard-4"
        service_account = {
          email  = "default"
          scopes = ["https://www.googleapis.com/auth/cloud-platform"]
        }
        shielded_instance_config = {
          enable_integrity_monitoring = true
          enable_secure_boot          = true
          enable_vtpm                 = true
        }
      },
    ]
    # Options
    enable_job_exclusive    = false
    enable_placement_groups = false
  },
  {
    partition_name = "shield"
    partition_conf = {
      ResumeTimeout  = 300
      SuspendTimeout = 300
      SuspendTime    = 300
    }
    partition_nodes = [
      {
        # Group Definition
        group_name             = "n4"
        node_count_dynamic_max = 10

        # Template By Definition
        disk_size_gb       = 32
        disk_type          = "pd-standard"
        enable_shielded_vm = true
        machine_type       = "n1-standard-4"
        service_account = {
          email = "default"
          scopes = [
            "https://www.googleapis.com/auth/cloud-platform",
          ]
        }
        shielded_instance_config = {
          enable_integrity_monitoring = true
          enable_secure_boot          = true
          enable_vtpm                 = true
        }
      },
    ]
    # Options
    enable_job_exclusive    = false
    enable_placement_groups = false
  },
]
