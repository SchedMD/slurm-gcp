#!/usr/bin/env python3
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

from datetime import datetime
import argparse
import json
from util import lkp, publish_message


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("topic_id", help="Pubsub topic ID to publish to")
    parser.add_argument(
        "--type",
        "-t",
        choices=["reconfig", "restart", "devel"],
        help="Notify message type",
    )

    args = parser.parse_args()

    message_json = json.dumps(
        {
            "request": args.type,
            "timestamp": datetime.utcnow().isoformat(),
        }
    )
    publish_message(lkp.project, args.topic_id, message_json)


if __name__ == "__main__":
    main()
