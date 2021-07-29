# Copyright 2021 SchedMD LLC.
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

# -*- mode: ruby -*-
# vi: set ft=ruby :

@vagrant_home = "/home/vagrant"
@ansible_home = "/vagrant"

Vagrant.configure("2") do |config|
  config.vm.disk :disk, size: "32GB", primary: true

  # Ubuntu 20.04 LTS
  config.vm.define "ubuntu2004" do |ubuntu2004|
    ubuntu2004.vm.box = "generic/ubuntu2004"
  end

  # Debian 10
  config.vm.define "debian10" do |debian10|
    debian10.vm.box = "generic/debian10"
  end

  # CentOS 7
  config.vm.define "centos7" do |centos7|
    centos7.vm.box = "generic/centos7"
  end

  # # RHEL 7
  # config.vm.define "rhel7" do |rhel7|
  #   config.vm.box = "generic/rhel7"
  # end

  # Copy the Ansible playbook over to the guest machine, run rsync-auto to automatically
  # pull in the latest changes while a VM is running.
  config.vm.synced_folder "ansible", "#{@ansible_home}", type: 'rsync', owner: "vagrant", group: "vagrant"

  config.vm.provision "ansible_local" do |ansible|
    ansible.playbook = "#{@ansible_home}/playbook.yml"
    ansible.verbose = "vvv"
  end
end
