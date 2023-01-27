
#project_id = "<PROJECT_ID>"

#slurm_cluster_name = "basic"

region = "us-central1"

enable_bigquery_load         = false
enable_cleanup_compute       = true
enable_cleanup_subscriptions = false
enable_reconfigure           = false

controller_instance_config = {
  access_config            = []
  additional_disks         = []
  can_ip_forward           = false
  disable_smt              = false
  disk_auto_delete         = true
  disk_labels              = null
  disk_size_gb             = null
  disk_type                = null
  enable_confidential_vm   = false
  enable_oslogin           = true
  enable_shielded_vm       = false
  gpu                      = null
  instance_template        = null
  labels                   = null
  machine_type             = "n1-standard-8"
  metadata                 = null
  min_cpu_platform         = null
  network_ip               = null
  on_host_maintenance      = null
  preemptible              = false
  service_account          = null
  shielded_instance_config = null
  region                   = null
  source_image_family      = $image_family
  source_image_project     = $image_project
  source_image             = $image
  static_ip                = null
  subnetwork_project       = null
  subnetwork               = "default"
  tags                     = []
  zone                     = null
}

login_nodes = [
  {
    # Group Definition
    group_name = "l0"

    # Template By Definition
    additional_disks       = []
    can_ip_forward         = false
    disable_smt            = false
    disk_auto_delete       = true
    disk_labels            = {}
    disk_size_gb           = 32
    disk_type              = "pd-standard"
    enable_confidential_vm = false
    enable_oslogin         = true
    enable_shielded_vm     = false
    gpu                    = null
    labels                 = {}
    machine_type           = "n1-standard-1"
    metadata               = {}
    min_cpu_platform       = null
    on_host_maintenance    = null
    preemptible            = false
    service_account = {
      email = "default"
      scopes = [
        "https://www.googleapis.com/auth/cloud-platform",
      ]
    }
    shielded_instance_config = null
    source_image_family      = $image_family
    source_image_project     = $image_project
    source_image             = $image
    tags                     = []

    # Template By Source
    instance_template = null

    # Instance Definition
    access_config      = []
    network_ips        = []
    num_instances      = 1
    region             = null
    static_ips         = []
    subnetwork_project = null
    subnetwork         = "default"
    zone               = null
  },
]

partitions = [
  {
    enable_job_exclusive    = false
    enable_placement_groups = false
    network_storage         = []
    partition_conf = {
      Default        = "YES"
      ResumeTimeout  = 300
      SuspendTimeout = 300
      SuspendTime    = 300
    }
    partition_startup_scripts_timeout = 300
    partition_startup_scripts = [
      # {
      #   filename = "hello_part_debug.sh"
      #   content  = <<EOF
      # #!/bin/bash
      # set -ex
      # echo "Hello, $$(hostname) from $$(dirname $$0) !"
      #   EOF
      #
      #},
    ]
    partition_name = "debug"
    partition_nodes = [
      {
        # Group Definition
        group_name             = "n1"
        node_count_dynamic_max = 20
        node_count_static      = 1
        node_conf = {
          Features = "test"
        }

        # Template By Definition
        additional_disks       = []
        can_ip_forward         = false
        disable_smt            = false
        disk_auto_delete       = true
        disk_labels            = {}
        disk_size_gb           = 32
        disk_type              = "pd-standard"
        enable_confidential_vm = false
        enable_oslogin         = true
        enable_shielded_vm     = false
        gpu                    = null
        labels                 = {}
        machine_type           = "n1-standard-2"
        metadata               = {}
        min_cpu_platform       = null
        on_host_maintenance    = null
        preemptible            = false
        service_account = {
          email = "default"
          scopes = [
            "https://www.googleapis.com/auth/cloud-platform",
          ]
        }
        shielded_instance_config = null
        source_image_family      = $image_family
        source_image_project     = $image_project
        source_image             = $image
        tags                     = []

        # Template By Source
        instance_template = null

        # Instance Definition
        access_config = [
          # {
          #   network_tier = null
          #
          #},
        ]
        bandwidth_tier = "platform_default"
        enable_spot_vm = false
        spot_instance_config = {
          termination_action = "STOP"
        }
      },
    ]
    region             = null
    subnetwork_project = null
    subnetwork         = "default"
    zone_policy_allow  = []
    zone_policy_deny   = []
  },
  {
    enable_job_exclusive    = false
    enable_placement_groups = false
    network_storage         = []
    partition_conf = {
      ResumeTimeout  = 300
      SuspendTimeout = 300
      SuspendTime    = 300
    }
    partition_startup_scripts_timeout = 300
    partition_startup_scripts         = []
    partition_name                    = "gpu"
    partition_nodes = [
      {
        # Group Definition
        group_name             = "v100"
        node_count_dynamic_max = 10
        node_count_static      = 0
        node_conf              = {}

        # Template By Definition
        additional_disks       = []
        can_ip_forward         = false
        disable_smt            = false
        disk_auto_delete       = true
        disk_labels            = {}
        disk_size_gb           = 32
        disk_type              = "pd-standard"
        enable_confidential_vm = false
        enable_oslogin         = true
        enable_shielded_vm     = false
        gpu = {
          count = 1
          type  = "nvidia-tesla-v100"
        }
        labels              = {}
        machine_type        = "n1-standard-4"
        metadata            = {}
        min_cpu_platform    = null
        on_host_maintenance = null
        preemptible         = false
        service_account = {
          email = "default"
          scopes = [
            "https://www.googleapis.com/auth/cloud-platform",
          ]
        }
        shielded_instance_config = null
        source_image_family      = $image_family
        source_image_project     = $image_project
        source_image             = $image
        tags                     = []

        # Template By Source
        instance_template = null

        # Instance Definition
        access_config  = []
        bandwidth_tier = "platform_default"
        enable_spot_vm = false
        spot_instance_config = {
          termination_action = "STOP"
        }
      },
    ]
    region             = null
    subnetwork_project = null
    subnetwork         = "default"
    zone_policy_allow  = []
    zone_policy_deny   = []
  },
  {
    enable_job_exclusive    = true
    enable_placement_groups = true
    network_storage         = []
    partition_conf = {
      Default        = "YES"
      ResumeTimeout  = 300
      SuspendTimeout = 300
      SuspendTime    = 300
    }
    partition_startup_scripts_timeout = 300
    partition_startup_scripts = [
      # {
      #   filename = "hello_part_debug.sh"
      #   content  = <<EOF
      # #!/bin/bash
      # set -ex
      # echo "Hello, $$(hostname) from $$(dirname $$0) !"
      #   EOF
      #
      #},
    ]
    partition_name = "c2"
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
        additional_disks       = []
        can_ip_forward         = false
        disable_smt            = false
        disk_auto_delete       = true
        disk_labels            = {}
        disk_size_gb           = 32
        disk_type              = "pd-standard"
        enable_confidential_vm = false
        enable_oslogin         = true
        enable_shielded_vm     = false
        gpu                    = null
        labels                 = {}
        machine_type           = "c2-standard-4"
        metadata               = {}
        min_cpu_platform       = null
        on_host_maintenance    = null
        preemptible            = false
        service_account = {
          email = "default"
          scopes = [
            "https://www.googleapis.com/auth/cloud-platform",
          ]
        }
        shielded_instance_config = null
        source_image_family      = $image_family
        source_image_project     = $image_project
        source_image             = $image
        tags                     = []

        # Template By Source
        instance_template = null

        # Instance Definition
        access_config = [
          # {
          #   network_tier = null
          #
          #},
        ]
        bandwidth_tier = "platform_default"
        enable_spot_vm = false
        spot_instance_config = {
          termination_action = "STOP"
        }
      },
    ]
    region             = null
    subnetwork_project = null
    subnetwork         = "default"
    zone_policy_allow  = []
    zone_policy_deny   = []
  },
  {
    enable_job_exclusive    = false
    enable_placement_groups = true
    network_storage         = []
    partition_conf = {
      Default        = "YES"
      ResumeTimeout  = 300
      SuspendTimeout = 300
      SuspendTime    = 300
    }
    partition_startup_scripts_timeout = 300
    partition_startup_scripts = [
      # {
      #   filename = "hello_part_debug.sh"
      #   content  = <<EOF
      # #!/bin/bash
      # set -ex
      # echo "Hello, $$(hostname) from $$(dirname $$0) !"
      #   EOF
      #
      #},
    ]
    partition_name = "spot"
    partition_nodes = [
      {
        # Group Definition
        group_name             = "n1"
        node_count_dynamic_max = 10
        node_count_static      = 0
        node_conf = {
          Features = "test"
        }

        # Template By Definition
        additional_disks       = []
        can_ip_forward         = false
        disable_smt            = false
        disk_auto_delete       = true
        disk_labels            = {}
        disk_size_gb           = 32
        disk_type              = "pd-standard"
        enable_confidential_vm = false
        enable_oslogin         = true
        enable_shielded_vm     = false
        gpu                    = null
        labels                 = {}
        machine_type           = "n1-standard-2"
        metadata               = {}
        min_cpu_platform       = null
        on_host_maintenance    = null
        preemptible            = true
        service_account = {
          email = "default"
          scopes = [
            "https://www.googleapis.com/auth/cloud-platform",
          ]
        }
        shielded_instance_config = null
        source_image_family      = $image_family
        source_image_project     = $image_project
        source_image             = $image
        tags                     = []

        # Template By Source
        instance_template = null

        # Instance Definition
        access_config = [
          # {
          #   network_tier = null
          #
          #},
        ]
        bandwidth_tier = "platform_default"
        enable_spot_vm = true
        spot_instance_config = {
          termination_action = "STOP"
        }
      },
    ]
    region             = null
    subnetwork_project = null
    subnetwork         = "default"
    zone_policy_allow  = []
    zone_policy_deny   = []
  },
]
