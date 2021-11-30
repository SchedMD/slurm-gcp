/**
 * Copyright 2021 SchedMD LLC
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

###########
# GENERAL #
###########

variable "project_id" {
  type        = string
  description = "Project ID of the project that holds the network."
}

variable "network_name" {
  type        = string
  description = "Name of the network this set of firewall rules applies to."
}

variable "cluster_name" {
  type        = string
  description = "Cluster name, used resource naming."
}

##############
# SLURM RULE #
##############

variable "source_tags" {
  type        = list(string)
  description = <<EOD
If source tags are specified, the firewall will apply only to traffic with
source IP that belongs to a tag listed in source tags. Source tags cannot
be used to control traffic to an instance's external IP address. Because tags
are associated with an instance, not an IP address. One or both of
sourceRanges and sourceTags may be set. If both properties are set, the firewall
will apply to traffic that has source IP address within sourceRanges OR the
source IP that belongs to a tag listed in the sourceTags property. The
connection does not need to match both properties for the firewall to apply.
EOD
  default     = []
}

variable "source_service_accounts" {
  type        = list(string)
  description = <<EOD
If source service accounts are specified, the firewall will apply only to
traffic originating from an instance with a service account in this list. Source
service accounts cannot be used to control traffic to an instance's external IP
address because service accounts are associated with an instance, not an IP
address. sourceRanges can be set at the same time as sourceServiceAccounts. If
both are set, the firewall will apply to traffic that has source IP address
within sourceRanges OR the source IP belongs to an instance with service account
listed in sourceServiceAccount. The connection does not need to match both
properties for the firewall to apply. sourceServiceAccounts cannot be used at
the same time as sourceTags or targetTags.
EOD
  default     = null
}

variable "target_tags" {
  type        = list(string)
  description = <<EOD
A list of instance tags indicating sets of instances located in the network that
may make network connections as specified in allowed[]. If no targetTags are
specified, the firewall rule applies to all instances on the specified network.
EOD
  default     = []
}

variable "target_service_accounts" {
  type        = list(string)
  description = <<EOD
A list of service accounts indicating sets of instances located in the network
that may make network connections as specified in allowed[].
targetServiceAccounts cannot be used at the same time as targetTags or
sourceTags. If neither targetServiceAccounts nor targetTags are specified, the
firewall rule applies to all instances on the specified network.
EOD
  default     = null
}
