#!/bin/bash
apt update -y 2>/dev/null
apt install -y python3 python3-pip
apt install -y curl nfs-common cron sudo
python3 -m pip install --upgrade pip wheel setuptools
python3 -m pip install ansible
bash <(curl -sSL https://sdk.cloud.google.com) --disable-prompts --install-dir=/opt
ln -s /opt/google-cloud-sdk.staging/bin/gsutil /usr/local/bin/
ln -s /opt/google-cloud-sdk/bin/gcloud /usr/local/bin/
