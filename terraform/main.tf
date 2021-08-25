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
  network = (
    var.network.network != null
    ? var.network.network
    : ""
  )

  valid_network = (
    length(local.network) > 0
    ? local.network
    : module.vpc[0].vpc_info.network_name
  )

  network_count = (
    var.network.network != null || var.network.subnets != null
    ? 0
    : 1
  )

  subnets = (
    var.network.subnets != null
    ? var.network.subnets
    : []
  )

  valid_subnets = (
    length(local.subnets) > 0
    ? local.subnets
    : module.vpc[0].vpc_info.subnets_names
  )
}

### Metadata ###

locals {
  common_metadata = {
    enable-oslogin = "TRUE"
    VmDnsSetting   = "GlobalOnly"
  }
}

### Controller ###

locals {
  controller_count_per_region = (
    var.controller.count_regions_covered != null
    ? var.controller.count_regions_covered
    : 1
  )

  controller_count_regions_covered = (
    var.controller.count_regions_covered != null
    ? var.controller.count_regions_covered
    : 1
  )

  controller_config = jsonencode({
    ### setup ###
    cloudsql     = var.config.cloudsql
    cluster_name = var.cluster_name
    project      = var.project_id
    munge_key    = var.config.munge_key
    jwt_key      = var.config.jwt_key

    ### storage ###
    network_storage       = var.config.network_storage
    login_network_storage = var.config.login_network_storage

    ### slurm.conf ###
    suspend_time = var.config.suspend_time
  })

  controller_metadata_slurm = {
    config                    = local.controller_config
    cgroup_conf_tpl           = file("${path.module}/../etc/cgroup.conf.tpl")
    custom-compute-install    = file("${path.module}/../scripts/custom-compute-install")
    custom-controller-install = file("${path.module}/../scripts/custom-controller-install")
  }

  controller_metadata_devel = (
    var.enable_devel == true
    ? {
      setup-script      = file("${path.module}/../scripts/setup.py")
      slurm-resume      = file("${path.module}/../scripts/resume.py")
      slurm-suspend     = file("${path.module}/../scripts/suspend.py")
      slurm_conf_tpl    = file("${path.module}/../etc/slurm.conf.tpl")
      slurmdbd_conf_tpl = file("${path.module}/../etc/slurmdbd.conf.tpl")
      slurmsync         = file("${path.module}/../scripts/slurmsync.py")
      util-script       = file("${path.module}/../scripts/util.py")
    }
    : null
  )

  controller_metadata = merge(
    local.common_metadata,
    local.controller_metadata_slurm,
    local.controller_metadata_devel,
    var.controller.metadata,
    {
      google_mpi_tuning = var.controller.disable_smt == true ? "--nosmt" : null
    },
  )
}

### Login ###

locals {
  login_config = jsonencode({
    ### setup ###
    cluster_name = var.cluster_name
    munge_key    = var.config.munge_key

    ### storage ###
    network_storage       = var.config.network_storage
    login_network_storage = var.config.login_network_storage
  })

  login_metadata_slurm = {
    config                 = local.login_config
    custom-compute-install = file("${path.module}/../scripts/custom-compute-install")
  }

  login_metadata_devel = (
    var.enable_devel == true
    ? {
      setup-script = file("${path.module}/../scripts/setup.py")
      util-script  = file("${path.module}/../scripts/util.py")
    }
    : null
  )

  login_metadata = merge(
    local.common_metadata,
    local.login_metadata_slurm,
    local.login_metadata_devel,
    var.login.metadata,
    {
      google_mpi_tuning = var.login.disable_smt == true ? "--nosmt" : null
    }
  )
}

### Compute ###

locals {
  compute_map = var.compute != null ? var.compute : {}

  compute_config = jsonencode({
    ### setup ###
    cluster_name = var.cluster_name
    munge_key    = var.config.munge_key

    ### storage ###
    network_storage = var.config.network_storage
  })

  compute_metadata_slurm = {
    instance_type = "compute"

    config       = local.compute_config
    setup-script = file("${path.module}/../scripts/setup.py")
    util-script  = file("${path.module}/../scripts/util.py")
  }

  compute_metadata_devel = (
    var.enable_devel == true
    ? {
      instance_type = "compute"

      config       = local.compute_config
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

  project_id      = var.project_id
  cluster_name    = var.cluster_name
  subnets_regions = var.network.subnets_regions
}

##############
# CONTROLLER #
##############

module "controller" {
  source = "./modules/node"

  ### general ###
  project_id   = var.project_id
  cluster_name = var.cluster_name

  ### multitude ###
  count_per_region      = local.controller_count_per_region
  count_regions_covered = local.controller_count_regions_covered

  ### network ###
  subnetwork_project = var.network.subnetwork_project
  network            = local.valid_network
  subnets            = local.valid_subnets
  subnets_regions    = var.network.subnets_regions
  tags               = var.controller.tags

  ### template ###
  instance_template_project = var.controller.instance_template_project
  instance_template         = var.controller.instance_template
  name_prefix               = "${var.cluster_name}-controller"

  ### instance ###
  service_account          = var.controller.service_account
  machine_type             = var.controller.machine_type
  min_cpu_platform         = var.controller.min_cpu_platform
  gpu                      = var.controller.gpu
  shielded_instance_config = var.controller.shielded_instance_config
  enable_confidential_vm   = var.controller.enable_confidential_vm
  enable_shielded_vm       = var.controller.enable_shielded_vm
  preemptible              = var.controller.preemptible

  ### metadata ###
  metadata = local.controller_metadata

  ### source image ###
  source_image_project = var.controller.source_image_project
  source_image_family  = var.controller.source_image_family
  source_image         = var.controller.source_image

  ### disk ###
  disk_type        = var.controller.disk_type
  disk_size_gb     = var.controller.disk_size_gb
  disk_labels      = var.controller.disk_labels
  disk_auto_delete = var.controller.disk_auto_delete
  additional_disks = var.controller.additional_disks
}

#########
# LOGIN #
#########

module "login" {
  source = "./modules/node"

  ### general ###
  project_id   = var.project_id
  cluster_name = var.cluster_name

  ### multitude ###
  count_per_region      = var.login.count_per_region
  count_regions_covered = var.login.count_regions_covered

  ### network ###
  subnetwork_project = var.network.subnetwork_project
  network            = local.valid_network
  subnets            = local.valid_subnets
  subnets_regions    = var.network.subnets_regions
  tags               = var.login.tags

  ### template ###
  instance_template_project = var.login.instance_template_project
  instance_template         = var.login.instance_template
  name_prefix               = "${var.cluster_name}-login"

  ### instance ###
  service_account          = var.login.service_account
  machine_type             = var.login.machine_type
  min_cpu_platform         = var.login.min_cpu_platform
  gpu                      = var.login.gpu
  shielded_instance_config = var.login.shielded_instance_config
  enable_confidential_vm   = var.login.enable_confidential_vm
  enable_shielded_vm       = var.login.enable_shielded_vm
  preemptible              = var.login.preemptible

  ### metadata ###
  metadata = local.login_metadata

  ### source image ###
  source_image_project = var.login.source_image_project
  source_image_family  = var.login.source_image_family
  source_image         = var.login.source_image

  ### disk ###
  disk_type        = var.login.disk_type
  disk_size_gb     = var.login.disk_size_gb
  disk_labels      = var.login.disk_labels
  disk_auto_delete = var.login.disk_auto_delete
  additional_disks = var.login.additional_disks
}

###########
# COMPUTE #
###########

module "compute" {
  source = "./modules/node"

  for_each = local.compute_map

  ### general ###
  project_id   = var.project_id
  cluster_name = var.cluster_name

  ### multitude ###
  count_per_region      = 0
  count_regions_covered = 0

  ### network ###
  subnetwork_project = var.network.subnetwork_project
  network            = local.valid_network
  subnets            = local.valid_subnets
  subnets_regions    = var.network.subnets_regions
  tags               = each.value.tags

  ### template ###
  instance_template_project = each.value.instance_template_project
  instance_template         = each.value.instance_template
  name_prefix               = "${var.cluster_name}-compute-${each.key}"

  ### instance ###
  service_account          = each.value.service_account
  machine_type             = each.value.machine_type
  min_cpu_platform         = each.value.min_cpu_platform
  gpu                      = each.value.gpu
  shielded_instance_config = each.value.shielded_instance_config
  enable_confidential_vm   = each.value.enable_confidential_vm
  enable_shielded_vm       = each.value.enable_shielded_vm
  preemptible              = each.value.preemptible

  ### metadata ###
  metadata = merge(
    local.common_metadata,
    local.compute_metadata_slurm,
    local.compute_metadata_devel,
    each.value.metadata,
    {
      google_mpi_tuning = each.value.disable_smt == true ? "--nosmt" : null
    }
  )

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
