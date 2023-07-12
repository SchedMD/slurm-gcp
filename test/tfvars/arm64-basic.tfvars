region = "us-central1"

enable_bigquery_load   = true
enable_cleanup_compute = true

create_bucket = false
bucket_name   = "slurm-test"

controller_instance_config = {
  disk_size_gb = 32
  disk_type    = "pd-ssd"
  machine_type = "t2a-standard-8"
}

controller_startup_scripts = [
  {
    filename = "hello_controller.sh"
    content  = <<-EOF
        #!/bin/bash
        set -ex
        echo "Hello, $(hostname) from $(dirname $0) !"
        mkdir -p /slurm/out
        touch /slurm/out/controller
        EOF
  },
]

login_startup_scripts = [
  {
    filename = "hello_login.sh"
    content  = <<-EOF
        #!/bin/bash
        set -ex
        echo "Hello, $(hostname) from $(dirname $0) !"
        mkdir -p /slurm/out
        touch /slurm/out/login
        EOF
  },
  {
    filename = "login2.sh"
    content  = <<-EOF
        #!/bin/bash
        set -ex
        echo "Hello, $(hostname) from $(dirname $0) !"
        mkdir -p /slurm/out
        touch /slurm/out/login2
        EOF
  },
]

compute_startup_scripts = [
  {
    filename = "hello_compute.sh"
    content  = <<-EOF
        #!/bin/bash
        set -ex
        echo "Hello, $(hostname) from $(dirname $0) !"
        mkdir -p /slurm/out
        touch /slurm/out/compute
        EOF
  },
]

prolog_scripts = [
  {
    filename = "hello_prolog.sh"
    content  = <<-EOF
        #!/bin/bash
        set -ex
        echo "Hello, $(hostname) from $(dirname $0) !"
        mkdir -p /slurm/out
        touch /slurm/out/prolog_$SLURM_JOBID
        EOF
  },
]

epilog_scripts = [
  {
    filename = "hello_epilog.sh"
    content  = <<-EOF
        #!/bin/bash
        set -ex
        echo "Hello, $(hostname) from $(dirname $0) !"
        mkdir -p /slurm/out
        touch /slurm/out/epilog_$SLURM_JOBID
        EOF
  },
]

login_nodes = [
  {
    # Group Definition
    group_name = "frontend"

    # Template By Definition
    disk_size_gb = 32
    disk_type    = "pd-standard"
    machine_type = "t2a-standard-1"
    service_account = {
      email  = "default"
      scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    }

    # Instance Definition
    num_instances = 1
  },
]

nodeset = [
  {
    # Group Definition
    nodeset_name           = "t2a2"
    node_count_dynamic_max = 20
    node_count_static      = 1

    # Template By Definition
    disk_size_gb = 32
    disk_type    = "pd-standard"
    machine_type = "t2a-standard-2"
    service_account = {
      email  = "default"
      scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    }
  },
  {
    # Group Definition
    nodeset_name           = "t2s2spot"
    node_count_dynamic_max = 10

    # Template By Definition
    disk_size_gb = 32
    disk_type    = "pd-standard"
    machine_type = "t2a-standard-2"
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
  {
    # Group Definition
    nodeset_name           = "t2shield"
    node_count_dynamic_max = 10

    # Template By Definition
    disk_size_gb       = 32
    disk_type          = "pd-standard"
    enable_shielded_vm = true
    machine_type       = "t2a-standard-2"
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

partitions = [
  {
    partition_name    = "debug"
    partition_nodeset = ["t2a2", ]
    # Options
    default              = true
    enable_job_exclusive = false
    resume_timeout       = 300
    suspend_timeout      = 300
    suspend_time         = 300
  },
  {
    partition_name    = "spot"
    partition_nodeset = ["t2s2spot", ]
    # Options
    enable_job_exclusive = false
    resume_timeout       = 300
    suspend_timeout      = 300
    suspend_time         = 300
  },
  {
    partition_name    = "shield"
    partition_nodeset = ["t2shield", ]
    # Options
    enable_job_exclusive = false
    resume_timeout       = 300
    suspend_timeout      = 300
    suspend_time         = 300
  },
]
