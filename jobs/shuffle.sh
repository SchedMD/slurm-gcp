#!/usr/bin/env bash

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

set -ex

if [ -z "$MIGRATE_INPUT" ]
then
	echo "Error: missing required environment variable 'MIGRATE_INPUT'. \
		Aboring." >&2
	exit 1
elif [ -z "$MIGRATE_OUTPUT" ]
then
	echo "Error: missing required environment variable 'MIGRATE_OUTPUT'. \
		Aboring." >&2
	exit 1
fi

shuf --output=$MIGRATE_OUTPUT $MIGRATE_INPUT
