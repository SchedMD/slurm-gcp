### General ###

project_id = "<PROJECT_ID>"

cluster_name = "slurm"

# *NOT* intended for production use
# enable_devel = true

### Network ###

network = {
  subnetwork_project = null
  network            = null
  subnets            = null
  subnets_regions = [
    "us-west1",
    "us-central1",
    "us-east1",
  ]
}

### Configuration ###

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

### Controller ###

controller = {
  count_per_region      = 1
  count_regions_covered = 1

  ### network ###
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
    # "metadata0" = "value0"
    # "metadata1" = "value1"
  }

  ### image ###
  source_image_project = null
  source_image_family  = "projects/schedmd-slurm-public/global/images/family/schedmd-slurm-20-11-7-centos-7"
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

### Login ###

login = {
  count_per_region      = 1
  count_regions_covered = 1

  ### network ###
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
    # "metadata0" = "value0"
    # "metadata1" = "value1"
  }

  ### image ###
  source_image_project = null
  source_image_family  = "projects/schedmd-slurm-public/global/images/family/schedmd-slurm-20-11-7-centos-7"
  source_image         = null

  ### disk ###
  disk_labels = {
    # "label0" = "value0"
    # "label1" = "value1"
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

### Compute ###

compute = {
  bigcpu = {
    ### network ###
    tags = [
      # "tag0",
      # "tag1",
    ]

    ### template ###
    instance_template_project = null
    instance_template         = null

    ### instance ###
    machine_type     = "c2-standard-60"
    min_cpu_platform = null
    gpu              = null
    # gpu = {
    #   type  = "nvidia-tesla-k80"
    #   count = 1
    # }
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
    disable_smt            = false
    preemptible            = false

    ### metadata ###
    metadata = {
      # "metadata0" = "value0"
      # "metadata1" = "value1"
    }

    ### image ###
    source_image_project = null
    source_image_family  = "projects/schedmd-slurm-public/global/images/family/schedmd-slurm-20-11-7-centos-7"
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
  },
  biggpu = {
    ### network ###
    tags = [
      # "tag0",
      # "tag1",
    ]

    ### template ###
    instance_template_project = null
    instance_template         = null

    ### instance ###
    machine_type     = "a2-megagpu-16g"
    min_cpu_platform = null
    gpu              = null
    # gpu = {
    #   type  = "nvidia-tesla-t4"
    #   count = 8
    # }
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
    source_image_family  = "projects/schedmd-slurm-public/global/images/family/schedmd-slurm-20-11-7-centos-7"
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
  },
}
