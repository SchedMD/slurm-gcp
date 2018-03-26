#!/bin/bash
echo "Checking for CUDA and installing."
# Check for CUDA and try to install.
if ! rpm -q cuda-8-0; then
  curl -O https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/cuda-repo-rhel7-8.0.61-1.x86_64.rpm
  rpm -i --force ./cuda-repo-rhel7-8.0.61-1.x86_64.rpm
  yum clean all
  yum install epel-release -y
  yum update -y
  yum install cuda-8-0 -y
fi
# Verify that CUDA installed; retry if not.
if ! rpm -q cuda-8-0; then
  yum install cuda-8-0 -y
fi
# Enable persistence mode
nvidia-smi -pm 1