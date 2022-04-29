/**
 * Copyright (C) SchedMD LLC.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

##########
# LOCALS #
##########

locals {
  target_tags = concat([var.slurm_cluster_name], var.target_tags)

  firewall_rules = [
    {
      name                    = "${var.slurm_cluster_name}-allow-ssh-ingress"
      direction               = "INGRESS"
      ranges                  = ["0.0.0.0/0"]
      source_tags             = var.source_tags
      source_service_accounts = var.source_service_accounts
      target_tags             = local.target_tags
      target_service_accounts = var.target_service_accounts
      allow = [
        {
          protocol = "tcp"
          ports    = ["22"]
        },
      ]
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
    {
      name                    = "${var.slurm_cluster_name}-allow-iap-ingress"
      direction               = "INGRESS"
      ranges                  = ["35.235.240.0/20"]
      source_tags             = var.source_tags
      source_service_accounts = var.source_service_accounts
      target_tags             = local.target_tags
      target_service_accounts = var.target_service_accounts
      allow = [
        {
          protocol = "tcp"
          ports    = ["22", "8642", "6842"]
        },
      ]
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
    {
      name                    = "${var.slurm_cluster_name}-allow-internal-ingress"
      direction               = "INGRESS"
      ranges                  = ["0.0.0.0/0"]
      source_tags             = var.source_tags
      source_service_accounts = var.source_service_accounts
      target_tags             = local.target_tags
      target_service_accounts = var.target_service_accounts
      allow = [
        {
          protocol = "icmp"
          ports    = []
        },
        {
          protocol = "tcp"
          ports    = ["0-65535"]
        },
        {
          protocol = "udp"
          ports    = ["0-65535"]
        },
      ]
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
  ]

  rules = [
    for f in local.firewall_rules : {
      name                    = f.name
      direction               = f.direction
      priority                = lookup(f, "priority", null)
      description             = lookup(f, "description", null)
      ranges                  = lookup(f, "ranges", null)
      source_tags             = lookup(f, "source_tags", null)
      source_service_accounts = lookup(f, "source_service_accounts", null)
      target_tags             = lookup(f, "target_tags", null)
      target_service_accounts = lookup(f, "target_service_accounts", null)
      allow                   = lookup(f, "allow", [])
      deny                    = lookup(f, "deny", [])
      log_config              = lookup(f, "log_config", null)
    }
  ]
}

##################
# FIREWALL RULES #
##################

module "firewall_rules" {
  source  = "terraform-google-modules/network/google//modules/firewall-rules"
  version = "~> 4.0"

  project_id   = var.project_id
  network_name = var.network_name

  rules = local.rules
}
