#!/usr/bin/env bash

# Copyright 2022 SchedMD LLC
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

set -ex

SMB_WORKGROUP = "example"
SMB_REALM = "example.com"
SMB_SERVER = "ad-server"

WINBIND_JOIN = 'Administrator[%Password]'
WINBIND_TEMPLATE_HOMEDIR = '/home/%D/%U'
WINBIND_TEMPLATE_SHELL = "/bin/bash"

if ! [ -x $(command -v authconfig) ]
then
	echo "Binary 'authconfig' not found. Aborting." >&2
	exit 1
fi

NETBIOS_NAME="$(expr substr "$(hostname)" 1 15)"
SMB_CONF="/etc/samba/smb.conf"
if grep "netbios name = " ${SMB_CONF}
then
	# replace line
	sed -i.tmp "s/netbios name = .*/netbios name = ${NETBIOS_NAME}/g" ${SMB_CONF}
else
	# append line
	sed -i.tmp "/^\[global\]/a netbios name = ${NETBIOS_NAME}" ${SMB_CONF}
fi

authconfig \
	--enablewinbind \
	--enablewinbindauth \
	--smbsecurity=ads \
	--smbworkgroup=${SMB_WORKGROUP} \
	--smbrealm=${SMB_REALM} \
	--smbservers=${SMB_SERVER} \
	--winbindjoin=${WINBIND_JOIN} \
	--winbindtemplatehomedir=${WINBIND_TEMPLATE_HOMEDIR} \
	--winbindtemplateshell=${WINBIND_TEMPLATE_SHELL} \
	--enablewinbindusedefaultdomain \
	--enablelocauthorize \
	--enablewinbindoffline \
	--enablemkhomedir \
	--updateall
