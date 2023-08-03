# Copyright (C) SchedMD LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#################
# TPU VARIABLES #
#################

variable "tf_version" {
  description = "The tensoflow version to install in the docker image for the TPU."
  type        = string
}

variable "docker_image" {
  description = "The docker image to use for the TPU."
  type        = string
  default     = "ubuntu:20.04"
}
