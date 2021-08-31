###########
# GENERAL #
###########

project_id = "<PROJECT_ID>"

cluster_name = "example"

# *NOT* intended for production use
# enable_devel = true

###########
# NETWORK #
###########

network = {
  ### attach ###
  subnetwork_project = null
  network            = null
  subnets            = null

  ### generate ###
  auto_create_subnetworks = false
  subnets_spec = [
    {
      cidr   = "10.0.0.0/24"
      region = "us-central1"
    },
  ]
}

#################
# CONFIGURATION #
#################

config = {
  ### setup ###
  cloudsql  = null
  jwt_key   = null
  munge_key = null

  ### storage ###
  network_storage = [
    # {
    #   server_ip     = "<storage host>"
    #   remote_mount  = "/home"
    #   local_mount   = "/home"
    #   fs_type       = "nfs"
    #   mount_options = null
    # },
  ]
  login_network_storage = [
    # {
    #   server_ip     = "<storage host>"
    #   remote_mount  = "/net_storage"
    #   local_mount   = "/shared"
    #   fs_type       = "nfs"
    #   mount_options = null
    # },
  ]

  ### slurm.conf ###
  suspend_time = null
}

##############
# CONTROLLER #
##############

controller_templates = {
  "example-controller" = {
    ### network ###
    subnet_name   = null
    subnet_region = "us-central1"
    tags = [
      # "tag0",
      # "tag1",
    ]

    ### template ###
    instance_template_project = null
    instance_template         = null

    ### instance ###
    machine_type     = "n2d-standard-4"
    min_cpu_platform = null
    gpu              = null
    service_account  = null
    # service_account = {
    #   email  = "[ACCOUNT]@developer.gserviceaccount.com"
    #   scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    # }
    shielded_instance_config = null
    # shielded_instance_config = {
    #   enable_secure_boot          = true
    #   enable_vtpm                 = true
    #   enable_integrity_monitoring = true
    # }
    enable_confidential_vm = false
    enable_shielded_vm     = true
    disable_smt            = false
    preemptible            = false

    ### metadata ###
    metadata = {
      # metadata0 = "value0"
      # metadata1 = "value1"
    }

    ### image ###
    source_image_project = null
    source_image_family  = null
    source_image         = null

    ### disk ###
    disk_labels = {
      # label0 = "value0"
      # label1 = "value1"
    }
    disk_size_gb     = 64
    disk_type        = "pd-standard"
    disk_auto_delete = true
    additional_disks = [
      # {
      #   disk_name    = null
      #   device_name  = null
      #   disk_size_gb = 128
      #   disk_type    = "pd-ssd"
      #   disk_labels  = null
      #   auto_delete  = true
      #   boot         = false
      # },
    ]
  }
}

controller_instances = [
  {
    template      = "example-controller"
    count_static  = 1
    subnet_name   = null
    subnet_region = "us-central1"
  },
]

#########
# LOGIN #
#########

login_templates = {
  "example-login" = {
    ### network ###
    subnet_name   = null
    subnet_region = "us-central1"
    tags = [
      # "tag0",
      # "tag1",
    ]

    ### template ###
    instance_template_project = null
    instance_template         = null

    ### instance ###
    machine_type     = "n2d-standard-2"
    min_cpu_platform = null
    gpu              = null
    service_account  = null
    # service_account = {
    #   email  = "[ACCOUNT]@developer.gserviceaccount.com"
    #   scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    # }
    shielded_instance_config = null
    # shielded_instance_config = {
    #   enable_secure_boot          = true
    #   enable_vtpm                 = true
    #   enable_integrity_monitoring = true
    # }
    enable_confidential_vm = false
    enable_shielded_vm     = true
    disable_smt            = false
    preemptible            = false

    ### metadata ###
    metadata = {
      # metadata0 = "value0"
      # metadata1 = "value1"
    }

    ### image ###
    source_image_project = null
    source_image_family  = null
    source_image         = null

    ### disk ###
    disk_labels = {
      # label0 = "value0"
      # label1 = "value1"
    }
    disk_size_gb     = 32
    disk_type        = "pd-standard"
    disk_auto_delete = true
    additional_disks = [
      # {
      #   disk_name    = null
      #   device_name  = null
      #   disk_size_gb = 128
      #   disk_type    = "pd-ssd"
      #   disk_labels = null
      #   auto_delete = true
      #   boot        = false
      # },
    ]
  }
}

login_instances = [
  {
    template      = "example-login"
    count_static  = 1
    subnet_name   = null
    subnet_region = "us-central1"
  },
]

###########
# COMPUTE #
###########

compute_templates = {
  "example-cpu" = {
    ### network ###
    subnet_name   = null
    subnet_region = "us-central1"
    tags = [
      # "tag0",
      # "tag1",
    ]

    ### template ###
    instance_template_project = null
    instance_template         = null

    ### instance ###
    machine_type     = "c2-standard-16"
    min_cpu_platform = null
    gpu              = null
    service_account  = null
    # service_account = {
    #   email  = "[ACCOUNT]@developer.gserviceaccount.com"
    #   scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    # }
    shielded_instance_config = null
    # shielded_instance_config = {
    #   enable_secure_boot          = true
    #   enable_vtpm                 = true
    #   enable_integrity_monitoring = true
    # }
    enable_confidential_vm = false
    enable_shielded_vm     = true
    disable_smt            = false
    preemptible            = false

    ### metadata ###
    metadata = {
      # "metadata0" = "value0"
      # "metadata1" = "value1"
    }

    ### image ###
    source_image_project = null
    source_image_family  = null
    source_image         = null

    ### disk ###
    disk_labels = {
      # "label0" = "value0"
      # "label1" = "value1"
    }
    disk_size_gb     = 64
    disk_type        = "pd-standard"
    disk_auto_delete = true
    additional_disks = [
      # {
      #   disk_name    = null
      #   device_name  = null
      #   disk_size_gb = 128
      #   disk_type    = "pd-ssd"
      #   disk_labels  = null
      #   auto_delete  = true
      #   boot         = false
      # },
    ]
  }
  "example-gpu" = {
    ### network ###
    subnet_name   = null
    subnet_region = "us-central1"
    tags = [
      # "tag0",
      # "tag1",
    ]

    ### template ###
    instance_template_project = null
    instance_template         = null

    ### instance ###
    machine_type     = "c2-standard-4"
    min_cpu_platform = null
    gpu = {
      type  = "nvidia-tesla-t4"
      count = 4
    }
    service_account = null
    # service_account = {
    #   email  = "[ACCOUNT]@developer.gserviceaccount.com"
    #   scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    # }
    shielded_instance_config = null
    # shielded_instance_config = {
    #   enable_secure_boot          = true
    #   enable_vtpm                 = true
    #   enable_integrity_monitoring = true
    # }
    enable_confidential_vm = false
    enable_shielded_vm     = true
    disable_smt            = true
    preemptible            = false

    ### metadata ###
    metadata = {
      # "metadata0" = "value0"
      # "metadata1" = "value1"
    }

    ### image ###
    source_image_project = null
    source_image_family  = null
    source_image         = null

    ### disk ###
    disk_labels = {
      # "label0" = "value0"
      # "label1" = "value1"
    }
    disk_size_gb     = 64
    disk_type        = "pd-standard"
    disk_auto_delete = true
    additional_disks = [
      # {
      #   disk_name    = null
      #   device_name  = null
      #   disk_size_gb = 256
      #   disk_type    = "pd-ssd"
      #   disk_labels  = null
      #   auto_delete  = true
      #   boot         = false
      # },
    ]
  }
}

##############
# PARTITIONS #
##############

partitions = {
  "example-partition" = {
    nodes = [
      {
        template      = "example-cpu"
        count_static  = 0
        count_dynamic = 10
        subnet_name   = null
        subnet_region = "us-central1"
      },
      {
        template      = "example-gpu"
        count_static  = 0
        count_dynamic = 5
        subnet_name   = null
        subnet_region = "us-central1"
      },
    ]
    conf = {
      MaxTime         = "UNLIMITED"
      DisableRootJobs = "NO"
    }
  }
}
