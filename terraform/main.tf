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
    var.network.subnetwork_project != null
    || var.network.network != null
    || var.network.subnets != null
    ? 0
    : 1
  )

  subnet_default_name = (
    var.network.auto_create_subnetworks == true
    ? module.vpc[0].vpc.network.network_name
    : "${var.cluster_name}-subnet"
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
  controller_templates = (
    var.controller_templates != null
    ? var.controller_templates
    : {}
  )

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
    project      = var.project_id
    munge_key    = var.config.munge_key
    jwt_key      = var.config.jwt_key

    ### storage ###
    network_storage       = var.config.network_storage
    login_network_storage = var.config.login_network_storage

    ### slurm.conf ###
    suspend_time = var.config.suspend_time
    partitions   = var.partitions
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
}

### Login ###

locals {
  login_templates = (
    var.login_templates != null
    ? var.login_templates
    : {}
  )

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
}

### Compute ###

locals {
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

########
# DATA #
########

### Controller ###

data "google_compute_subnetwork" "controller_subnetwork" {
  depends_on = [
    module.vpc,
  ]

  for_each = local.controller_instances_map

  project = lookup(var.network, "subnetwork_project", var.project_id)
  name    = each.value.subnet_name != null ? each.value.subnet_name : local.subnet_default_name
  region  = each.value.subnet_region
}

### Login ###

data "google_compute_subnetwork" "login_subnetwork" {
  depends_on = [
    module.vpc,
  ]

  for_each = local.login_instances_map

  project = lookup(var.network, "subnetwork_project", var.project_id)
  name    = each.value.subnet_name != null ? each.value.subnet_name : local.subnet_default_name
  region  = each.value.subnet_region
}

### Compute ###

data "google_compute_subnetwork" "compute_subnetwork" {
  depends_on = [
    module.vpc,
  ]

  for_each = local.compute_templates

  project = lookup(var.network, "subnetwork_project", var.project_id)
  name    = each.value.subnet_name != null ? each.value.subnet_name : local.subnet_default_name
  region  = each.value.subnet_region
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
  source = "./modules/node_template"

  for_each = local.controller_templates

  ### general ###
  project_id   = var.project_id
  cluster_name = var.cluster_name

  ### network ###
  subnetwork_project = var.network.subnetwork_project
  network            = module.vpc[0].vpc.network.network.self_link
  subnetwork = (
    data.google_compute_subnetwork.controller_subnetwork[
      "${each.value.subnet_region}/${each.value.subnet_name != null ? each.value.subnet_name : local.subnet_default_name}"
    ].self_link
  )
  region = (
    data.google_compute_subnetwork.controller_subnetwork[
      "${each.value.subnet_region}/${each.value.subnet_name != null ? each.value.subnet_name : local.subnet_default_name}"
    ].region
  )
  tags = each.value.tags

  ### template ###
  instance_template_project = each.value.instance_template_project
  instance_template         = each.value.instance_template
  name_prefix               = "${var.cluster_name}-controller"

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
    local.controller_metadata_slurm,
    local.controller_metadata_devel,
    each.value.metadata,
    {
      google_mpi_tuning = each.value.disable_smt == true ? "--nosmt" : null
    },
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

### Instance ###

module "controller_instance" {
  source  = "terraform-google-modules/vm/google//modules/compute_instance"
  version = "~> 7.1"

  for_each = local.controller_instances_map

  ### network ###
  subnetwork_project = var.network.subnetwork_project
  network            = module.vpc[0].vpc.network.network.self_link
  subnetwork         = each.value.subnet_name != null ? each.value.subnet_name : local.subnet_default_name
  region             = each.value.subnet_region

  ### instance ###
  instance_template = module.controller_template[each.value.template].self_link
  num_instances     = each.value.count_static
  hostname          = "${var.cluster_name}-controller-${each.value.subnet_region}"
}

#########
# LOGIN #
#########

### Template ###

module "login_template" {
  source = "./modules/node_template"

  for_each = local.login_templates

  ### general ###
  project_id   = var.project_id
  cluster_name = var.cluster_name

  ### network ###
  subnetwork_project = var.network.subnetwork_project
  network            = module.vpc[0].vpc.network.network.self_link
  subnetwork = (
    data.google_compute_subnetwork.login_subnetwork[
      "${each.value.subnet_region}/${each.value.subnet_name != null ? each.value.subnet_name : local.subnet_default_name}"
    ].self_link
  )
  region = (
    data.google_compute_subnetwork.login_subnetwork[
      "${each.value.subnet_region}/${each.value.subnet_name != null ? each.value.subnet_name : local.subnet_default_name}"
    ].region
  )
  tags = each.value.tags

  ### template ###
  instance_template_project = each.value.instance_template_project
  instance_template         = each.value.instance_template
  name_prefix               = "${var.cluster_name}-login"

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
    local.login_metadata_slurm,
    local.login_metadata_devel,
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

### Instance ###

module "login_instance" {
  source  = "terraform-google-modules/vm/google//modules/compute_instance"
  version = "~> 7.1"

  for_each = local.login_instances_map

  ### network ###
  subnetwork_project = var.network.subnetwork_project
  network            = module.vpc[0].vpc.network.network.self_link
  subnetwork         = each.value.subnet_name != null ? each.value.subnet_name : local.subnet_default_name
  region             = each.value.subnet_region

  ### instance ###
  instance_template = module.login_template[each.value.template].self_link
  num_instances     = each.value.count_static
  hostname          = "${var.cluster_name}-login-${each.value.subnet_region}"
}

###########
# COMPUTE #
###########

### Template ###

module "compute_template" {
  source = "./modules/node_template"

  for_each = local.compute_templates

  ### general ###
  project_id   = var.project_id
  cluster_name = var.cluster_name

  ### network ###
  subnetwork_project = var.network.subnetwork_project
  network            = module.vpc[0].vpc.network.network.self_link
  subnetwork         = data.google_compute_subnetwork.compute_subnetwork[each.key].self_link
  region             = data.google_compute_subnetwork.compute_subnetwork[each.key].region
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
