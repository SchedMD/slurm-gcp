# Copyright 2021 SchedMD LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

##########
# LOCALS #
##########

### Network ###

locals {
  network_count = (
    var.network.network != null
    ? 0
    : 1
  )

  network = (
    var.network.network != null
    ? var.network.network
    : module.vpc[0].vpc.network.network.self_link
  )

  subnet_default_name = (
    var.network.auto_create_subnetworks == true
    && local.network_count == 1
    ? module.vpc[0].vpc.network.network_name
    : "${var.cluster_name}-subnet"
  )
}

### Configuration ###

locals {
  cgroup_conf_tpl = (
    var.config.cgroup_conf_tpl != null
    ? var.config.cgroup_conf_tpl
    : "${path.module}/../etc/cgroup.conf.tpl"
  )

  slurm_conf_tpl = (
    var.config.slurm_conf_tpl != null
    ? var.config.slurm_conf_tpl
    : "${path.module}/../etc/slurm.conf.tpl"
  )

  slurmdbd_conf_tpl = (
    var.config.slurmdbd_conf_tpl != null
    ? var.config.slurmdbd_conf_tpl
    : "${path.module}/../etc/slurmdbd.conf.tpl"
  )

  controller_d = (
    var.config.controller_d != null
    ? var.config.controller_d
    : "${path.module}/../scripts/controller.d"
  )

  scripts_controller_d = {
    for script in fileset(local.controller_d, "[^.]*")
    : "custom-controller-${replace(script, "/[^a-zA-Z0-9-_]/", "_")}"
    => file("${local.controller_d}/${script}")
  }

  compute_d = (
    var.config.controller_d != null
    ? var.config.controller_d
    : "${path.module}/../scripts/compute.d"
  )

  scripts_compute_d = {
    for script in fileset(local.compute_d, "[^.]*")
    : "custom-compute-${replace(script, "/[^a-zA-Z0-9-_]/", "_")}"
    => file("${local.compute_d}/${script}")
  }
}

### Metadata ###

locals {
  common_metadata = {
    enable-oslogin = "TRUE"
    VmDnsSetting   = "GlobalOnly"

    cluster_name = var.cluster_name
  }

  controller = "${var.cluster_name}-controller"
}

### Controller ###

locals {
  controller_service_account = (
    {
      email = var.controller_service_account.email
      scopes = (
        var.controller_service_account.scopes != null
        ? var.controller_service_account.scopes
        : [
          "https://www.googleapis.com/auth/cloud-platform",
        ]
      )
    }
  )

  controller_templates = (
    var.controller_templates != null
    ? var.controller_templates
    : {}
  )

  controller_template_map = {
    for x in var.controller_templates
    : "${x.subnet_region}/${x.subnet_name != null ? x.subnet_name : local.subnet_default_name}" => {
      subnet_name   = x.subnet_name != null ? x.subnet_name : local.subnet_default_name
      subnet_region = x.subnet_region
    }
  }

  controller_instances_map = {
    for x in var.controller_instances
    : "${x.subnet_region}/${x.subnet_name != null ? x.subnet_name : local.subnet_default_name}" => {
      template      = x.template
      count_static  = x.count_static
      subnet_name   = x.subnet_name != null ? x.subnet_name : local.subnet_default_name
      subnet_region = x.subnet_region
    }
  }

  controller_config = jsonencode({
    ### setup ###
    cloudsql     = var.config.cloudsql
    cluster_name = var.cluster_name
    controller   = local.controller
    project      = var.project_id
    munge_key    = var.config.munge_key
    jwt_key      = var.config.jwt_key

    ### storage ###
    network_storage       = var.config.network_storage
    login_network_storage = var.config.login_network_storage

    ### slurm.conf ###
    partitions = var.partitions
  })

  controller_metadata_slurm = {
    instance_type = "controller"
    config        = local.controller_config

    cgroup_conf_tpl   = file(local.cgroup_conf_tpl)
    slurm_conf_tpl    = file(local.slurm_conf_tpl)
    slurmdbd_conf_tpl = file(local.slurmdbd_conf_tpl)
  }

  controller_metadata_devel = (
    var.enable_devel == true
    ? {
      setup-script  = file("${path.module}/../scripts/setup.py")
      slurm-resume  = file("${path.module}/../scripts/resume.py")
      slurm-suspend = file("${path.module}/../scripts/suspend.py")
      slurmsync     = file("${path.module}/../scripts/slurmsync.py")
      util-script   = file("${path.module}/../scripts/util.py")
    }
    : null
  )
}

### Login ###

locals {
  login_service_account = (
    {
      email = var.login_service_account.email
      scopes = (
        var.login_service_account.scopes != null
        ? var.login_service_account.scopes
        : [
          "https://www.googleapis.com/auth/cloud-platform",
        ]
      )
    }
  )

  login_templates = (
    var.login_templates != null
    ? var.login_templates
    : {}
  )

  login_template_map = {
    for x in var.login_templates
    : "${x.subnet_region}/${x.subnet_name != null ? x.subnet_name : local.subnet_default_name}" => {
      subnet_name   = x.subnet_name != null ? x.subnet_name : local.subnet_default_name
      subnet_region = x.subnet_region
    }
  }

  login_instances_map = {
    for x in var.login_instances
    : "${x.subnet_region}/${x.subnet_name != null ? x.subnet_name : local.subnet_default_name}" => {
      template      = x.template
      count_static  = x.count_static
      subnet_name   = x.subnet_name != null ? x.subnet_name : local.subnet_default_name
      subnet_region = x.subnet_region
    }
  }

  login_config = jsonencode({
    ### setup ###
    cluster_name = var.cluster_name
    controller   = local.controller
    munge_key    = var.config.munge_key

    ### storage ###
    network_storage       = var.config.network_storage
    login_network_storage = var.config.login_network_storage
  })

  login_metadata_slurm = {
    instance_type = "login"
    config        = local.login_config
  }

  login_metadata_devel = (
    var.enable_devel == true
    ? {
      setup-script = file("${path.module}/../scripts/setup.py")
      util-script  = file("${path.module}/../scripts/util.py")
    }
    : null
  )
}

### Compute ###

locals {
  compute_service_account = (
    {
      email = var.compute_service_account.email
      scopes = (
        var.compute_service_account.scopes != null
        ? var.compute_service_account.scopes
        : [
          "https://www.googleapis.com/auth/cloud-platform",
        ]
      )
    }
  )

  compute_templates = (
    var.compute_templates != null
    ? var.compute_templates
    : {}
  )

  compute_config = jsonencode({
    ### setup ###
    cluster_name = var.cluster_name
    munge_key    = var.config.munge_key

    ### storage ###
    network_storage = var.config.network_storage
  })

  compute_metadata_slurm = {
    instance_type = "compute"
    config        = local.compute_config
  }

  compute_metadata_devel = (
    var.enable_devel == true
    ? {
      setup-script = file("${path.module}/../scripts/setup.py")
      util-script  = file("${path.module}/../scripts/util.py")
    }
    : null
  )
}

############
# PROVIDER #
############

provider "google" {
  project = var.project_id
}

###########
# NETWORK #
###########

module "vpc" {
  source = "./modules/network"

  count = local.network_count

  ### general ###
  project_id   = var.project_id
  cluster_name = var.cluster_name

  ### network ###
  auto_create_subnetworks = var.network.auto_create_subnetworks
  subnets_spec            = var.network.subnets_spec
}

##############
# CONTROLLER #
##############

### Template ###

module "controller_template" {
  source = "./modules/instance_template"

  for_each = local.controller_templates

  ### general ###
  project_id   = var.project_id
  cluster_name = var.cluster_name

  ### network ###
  subnetwork_project = var.network.subnetwork_project
  network            = local.network
  subnetwork         = each.value.subnet_name != null ? each.value.subnet_name : local.subnet_default_name
  region             = each.value.subnet_region
  tags               = each.value.tags

  ### template ###
  instance_template_project = each.value.instance_template_project
  instance_template         = each.value.instance_template
  name_prefix               = local.controller

  ### instance ###
  service_account          = var.controller_service_account
  machine_type             = each.value.machine_type
  min_cpu_platform         = each.value.min_cpu_platform
  gpu                      = each.value.gpu
  shielded_instance_config = each.value.shielded_instance_config
  enable_confidential_vm   = each.value.enable_confidential_vm
  enable_shielded_vm       = each.value.enable_shielded_vm
  preemptible              = each.value.preemptible

  ### source image ###
  source_image_project = each.value.source_image_project
  source_image_family  = each.value.source_image_family
  source_image         = each.value.source_image

  ### disk ###
  disk_type        = each.value.disk_type
  disk_size_gb     = each.value.disk_size_gb
  disk_labels      = each.value.disk_labels
  disk_auto_delete = each.value.disk_auto_delete
  additional_disks = each.value.additional_disks
}

### Instance ###

module "controller_instance" {
  source = "./modules/compute_instance"

  for_each = local.controller_instances_map

  ### network ###
  subnetwork_project = var.network.subnetwork_project
  network            = local.network
  subnetwork         = each.value.subnet_name != null ? each.value.subnet_name : local.subnet_default_name
  region             = each.value.subnet_region

  ### instance ###
  instance_template   = module.controller_template[each.value.template].self_link
  num_instances       = each.value.count_static
  hostname            = local.controller
  add_hostname_suffix = false

  ### metadata ###
  metadata = merge(
    local.common_metadata,
    local.controller_metadata_slurm,
    local.controller_metadata_devel,
    local.scripts_controller_d,
    local.scripts_compute_d,
    {
      google_mpi_tuning = local.controller_templates[each.value.template].disable_smt == true ? "--nosmt" : null
    },
  )
}

#########
# LOGIN #
#########

### Template ###

module "login_template" {
  source = "./modules/instance_template"

  for_each = local.login_templates

  ### general ###
  project_id   = var.project_id
  cluster_name = var.cluster_name

  ### network ###
  subnetwork_project = var.network.subnetwork_project
  network            = local.network
  subnetwork         = each.value.subnet_name != null ? each.value.subnet_name : local.subnet_default_name
  region             = each.value.subnet_region
  tags               = each.value.tags

  ### template ###
  instance_template_project = each.value.instance_template_project
  instance_template         = each.value.instance_template
  name_prefix               = "${var.cluster_name}-login"

  ### instance ###
  service_account          = var.login_service_account
  machine_type             = each.value.machine_type
  min_cpu_platform         = each.value.min_cpu_platform
  gpu                      = each.value.gpu
  shielded_instance_config = each.value.shielded_instance_config
  enable_confidential_vm   = each.value.enable_confidential_vm
  enable_shielded_vm       = each.value.enable_shielded_vm
  preemptible              = each.value.preemptible

  ### source image ###
  source_image_project = each.value.source_image_project
  source_image_family  = each.value.source_image_family
  source_image         = each.value.source_image

  ### disk ###
  disk_type        = each.value.disk_type
  disk_size_gb     = each.value.disk_size_gb
  disk_labels      = each.value.disk_labels
  disk_auto_delete = each.value.disk_auto_delete
  additional_disks = each.value.additional_disks
}

### Instance ###

module "login_instance" {
  source = "./modules/compute_instance"

  for_each = local.login_instances_map

  ### network ###
  subnetwork_project = var.network.subnetwork_project
  network            = local.network
  subnetwork         = each.value.subnet_name != null ? each.value.subnet_name : local.subnet_default_name
  region             = each.value.subnet_region

  ### instance ###
  instance_template = module.login_template[each.value.template].self_link
  num_instances     = each.value.count_static
  hostname          = "${var.cluster_name}-login-${each.value.subnet_region}"

  ### metadata ###
  metadata = merge(
    local.common_metadata,
    local.login_metadata_slurm,
    local.login_metadata_devel,
    local.scripts_compute_d,
    {
      google_mpi_tuning = local.login_templates[each.value.template].disable_smt == true ? "--nosmt" : null
    },
  )
}

###########
# COMPUTE #
###########

### Template ###

module "compute_template" {
  source = "./modules/instance_template"

  for_each = local.compute_templates

  ### general ###
  project_id   = var.project_id
  cluster_name = var.cluster_name

  ### network ###
  subnetwork_project = var.network.subnetwork_project
  network            = local.network
  subnetwork         = each.value.subnet_name != null ? each.value.subnet_name : local.subnet_default_name
  region             = each.value.subnet_region
  tags               = each.value.tags

  ### template ###
  instance_template_project = each.value.instance_template_project
  instance_template         = each.value.instance_template
  name_prefix               = "${var.cluster_name}-compute-${each.key}"

  ### instance ###
  service_account          = var.compute_service_account
  machine_type             = each.value.machine_type
  min_cpu_platform         = each.value.min_cpu_platform
  gpu                      = each.value.gpu
  shielded_instance_config = each.value.shielded_instance_config
  enable_confidential_vm   = each.value.enable_confidential_vm
  enable_shielded_vm       = each.value.enable_shielded_vm
  preemptible              = each.value.preemptible

  ### source image ###
  source_image_project = each.value.source_image_project
  source_image_family  = each.value.source_image_family
  source_image         = each.value.source_image

  ### disk ###
  disk_type        = each.value.disk_type
  disk_size_gb     = each.value.disk_size_gb
  disk_labels      = each.value.disk_labels
  disk_auto_delete = each.value.disk_auto_delete
  additional_disks = each.value.additional_disks
}

### Metadata ###

resource "google_compute_project_metadata_item" "compute_metadata" {
  project = var.project_id

  key = "${var.cluster_name}-compute-metadata"
  value = jsonencode(merge(
    local.common_metadata,
    local.compute_metadata_slurm,
    local.compute_metadata_devel,
    local.scripts_compute_d,
    module.compute_template,
  ))
}
