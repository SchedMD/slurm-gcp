  
# Using TPUs with Slurm GCP

This is the Alpha release of Slurm that supports scheduling of jobs in Cloud TPU-VM. This installation includes additional steps not found in the [official GCP slurm installation](https://github.com/SchedMD/slurm-gcp) that include staging Slurm binaries in an external mount such as filestore.

Please note that this MVP does not work with Cloud TPU Nodes.

# Installation 

The slurm for Cloud TPU is under active developement under the `tpu-vm` branch

```bash
git clone https://github.com/SchedMD/slurm-gcp.git .
git checkout tpu-vm
```

## NFS share to store the slurm Binaries

The cloud TPU-VM worker nodes require access to the slurm binaries. The current installation procedure requires that you store the Slurm binaries in an NFS share, such as filestore and make them avaiable to the Cloud TPU-VM workers. This step is required to reduce the boot up time because there currently does not exist a Slurm customized tpu-vm image, this might change in the future. 

Staging of the binaries is a two step process 1) Create the NFS share, then  2) Use Slurm's [foundry.py](../foundry/foundry.py) script to stage the files in the NFS share


### **Create a NFS share**

Create NFS share using filestore and and grab the ip address. If you are using a custom network other than the `default` network , you can include the optional flag `--network=name="network-other-than-default"` to ensure NFS share is created on custom network.

```bash
cloudshell$ gcloud beta filestore instances create slurm-nfs --zone=europe-west4-a --tier=BASIC_HDD --file-share=name="custom-slurm-nfs",capacity=1TB 
```

Grab the `filestore location` and `filestore ip` and use that in the next step below

```
cloudshell$ gcloud beta filestore instances list
INSTANCE_NAME: nfs-server
LOCATION: europe-west4-a
TIER: BASIC_HDD
CAPACITY_GB: 1024
FILE_SHARE_NAME: custom-slurm-nfs
IP_ADDRESS: 10.1.1.2
STATE: READY
CREATE_TIME: 2022-06-21T14:01:17
```

### **Modify the `images.yaml` with the nessary medatadata to compile the slurm binary.**

Modify the [images.yaml](../foundry/images.yaml) with the  `filestore location` and `filestore ip`. 

Make sure that the base image is set to `Ubuntu 20.04` in the [images.yaml](../foundry/images.yaml), this is the version that Ubuntu version that TPU VM instances run.

```
cloudshell$ cat foundry/images.yaml
...
  foundry/images.yaml
  images:
    - base: ubuntu-2004
      base_image: projects/ubuntu-os-cloud/global/images/family/ubuntu-2004-lts
      metadata:
        external-slurm-install: |
          remote: 10.1.1.2:/custom-slurm-nfs
          mount: /opt/slurm
          type: nfs
...
```

### **Use the Cloud Foundry Script to compile and stage the files in the NFS share share**

SchedMD has provided the [external_install_slurm.py](../foundry/custom.d/external_install_slurm.py) script that will compile and install
slurm to the external mount location in the metadata. The process of creating this image and installing Slurm to the external mount could take as much as **40 minutes**. 

```bash
cloudshell$ cd foundry/scripts
cloudshell$ pipenv run ./foundry.py slurm-image-foundry --pause
```
`--pause` causes foundry not to actually make the image, but only stage the binaries.

# Install Slurm 

The rest of the Slurm installation follows the offical Slurm GCP installation guide with a quick summary below.  

### **Edit the tfvars**

Modify the cloud TPU-VM partition configuration in [basic.tfvars](../tf/examples/basic/basic.tfvars.example) file

- Modify the project name and default networks

```
...
cluster_name = "g1"
project      = "<project>"
zone         = "us-central1-a"

network_name            = "default"
# subnetwork_name       = "default"
...
```

- For machine type pick the appropriate generation 
```
Use "n1-356-96-tpu" for v2
Use "n1-340-48-tpu" for v3
Use "n2d-407-240-tpu" for v4
```

- Under network storage, specify the `filestore location` and `filestore ip` from the NFS share. 
- There should not be any static nodes in this partition; it won't work.
- The partition is not strictly required to be exclusive, but it is preferred. That way the TPU is allocated and torn down for each job.
- Only a single node is allowed per job on this partition.

```bash
cloudshell$ cat tf/examples/basic/basic.tfvars.example
....
{ name                 = "v2_32_v2_alpha"
    machine_type         = "n1-356-96-tpu"
    static_node_count    = 0
    max_node_count       = 10
    zone                 = "europe-west4-a"
    image                = null
    image_hyperthreads   = true
    compute_disk_type    = "pd-standard"
    compute_disk_size_gb = 20
    compute_labels       = {}
    cpu_platform         = null
    gpu_count            = 0
    gpu_type             = null
    network_storage      = [{
      server_ip     = "10.1.1.2"
      remote_mount  = "/custom-slurm-nfs"
      local_mount   = "/opt/slurm"
      fs_type       = "nfs"
	  mount_options = null
    }]
    preemptible_bursting = false
    vpc_subnet           = "default"
    exclusive            = true
    enable_placement     = false
    regional_capacity    = false
    regional_policy      = {}
    instance_template    = null
    tpu_type             = "v3-32"
    tpu_version          = "tpu-vm-base"
    tpu_args             = "--reserved"
  },
  ...
```

### **Initialize terraform and install slurm**

This will initialize the directory with Terraform configuration files and validate the configuration.

```bash
cloudshell$ cd tf/examples/basic/
cloudshell$ mv basic.tfvars.example basic.tfvars
cloudshell$ terraform init
cloudshell$ terraform validate
```

Then, apply the configuration.

```
cloudshell$ terraform apply -var-file=basic.tfvars
```

You will be prompted to accept the actions described, based on the configurations that’s been set. Enter “yes” to begin the deployment.

```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.
  Enter a value: yes
```

The operation can take a few minutes to complete, so please be patient.

Note: You may need to authorize gcloud to make a GCP API call. If so, click Authorize.

Once the deployment has completed you will see output similar to:

```
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:

cluster_name = "g1"
config = <sensitive>
controller_name = "g1-controller"
controller_network_ips = [
  "10.128.0.4",
]
login_names = [
  "g1-login0",
]
login_network_ips = [
  "10.128.0.5",
]
zone = "us-central1-a"
...
```
# Logging into the login node and launching a TPU job 

You can now ssh into the Slurm login node or Controller and launch a job, any will work
```bash
cloudshell$ gcloud compute ssh g1-controller
```
You can use the `sinfo` commands to view the status of the cluster, and  `salloc -N1 -p <TPU partition name>` to create a slurm job that put you on the TPU-VM.

```bash 
[admin_@g1-controller ~]$ sinfo
PARTITION       AVAIL  TIMELIMIT  NODES  STATE NODELIST
v2_32_v2_alpha*    up   infinite     10  idle~ g1-compute-0-[0-9]
[admin_@g1-controller ~]$ salloc -N1 -p v2_32_v2_alpha
salloc: Granted job allocation 2
salloc: Waiting for resource configuration

```

If you need access to slurm commands from within the TPU VM:

```bash
source /etc/profile.d/slurm.sh
sinfo
```
# How to run a job on all Cloud TPU workers using Slurm
When Slurm instantiates a TPU pod that includes N number of worker VMs, the the Slum daemon will only run  on Cloud TPU `worker0`. In order to execute a Slurm job that runs all the Cloud TPU workers, you will need to use the Cloud TPU [gcloud](https://cloud.google.com/sdk/gcloud/reference/alpha/compute/tpus/tpu-vm/ssh) command and include the flag `--worker-all` from Cloud TPU `worker0`. Below is an example of how this can be accomplished  directly on the Cloud TPU worker and in a Docker container. 

### Running a job on all Cloud TPU workers directly on  `worker0` OS (JAX example)

Create a script with your job code
```bash
cat <<EOF >> pod-train.sh
#!/bin/bash -xe 
export ZONE=europe-west4-a
gcloud compute tpus tpu-vm ssh \
	$SLURMD_NODENAME --zone ${ZONE} --worker=all --command \
	"\
	python3 -c \
	\"import jax; \
	print('global device count:', jax.device_count()); \
	print('local device count:', jax.local_device_count()) \
	\""
EOF
```

Change permissions on the file
```
chmod a+x pod-train.sh
```

Launch the Slurm job 

```
$ sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
v2_32*       up   infinite     10  idle~ g0-compute-0-[0-9]
v2_8         up   infinite     10  idle~ g0-compute-1-[0-9]

$ sbatch -N1 -p v2_32 pod-train.sh

```

The output file of the training job will look something similar to this
```
cat slurm.6
......
Warning: Permanently added 'tpu.83988282433886287-2-ka9f4w' (ECDSA) to the list of known hosts.
Warning: Permanently added 'tpu.83988282433886287-0-+hgdrs' (ECDSA) to the list of known hosts.
Warning: Permanently added 'tpu.83988282433886287-1-vb2vut' (ECDSA) to the list of known hosts.
Warning: Permanently added 'tpu.83988282433886287-3-m6blmv' (ECDSA) to the list of known hosts.
global device count: 32
local device count: 8
global device count: 32
local device count: 8
global device count: 32
local device count: 8
global device count: 32
local device count: 8
```
### Running a job on all Cloud TPU workers  using Docker containers (JAX example)
This example is based off the official how to guide for [Docker containers with Cloud TPU Pods](https://cloud.google.com/tpu/docs/run-in-container#tpu-pod_1)

Add this script to the [custom-compute-install](../scripts/custom-compute-install) script to to modify  `/etc/nsswitch.conf` during power on, allowing you to get elevate permissions (sudo) without a password. You will need to sudo to use Docker comamnds. 

```bash
echo <EOF > /scripts/custom-compute-install
#!/bin/sh
sed -e "s/slurm//g" -i /etc/nsswitch.conf *
EOF
```

Create a Artifactory Docker Repository 

```bash
export PROJECT=cloud-tpu-slurm-demo
export REPO_NAME=cloud-tpu-slurm-demo
export IMAGE_NAME=cloud-tpu-slurm-demo
export TAG=jax
export ZONE=europe-west4-a
export LOCATION=europe-west4

gcloud artifacts repositories create ${REPO_NAME} --repository-format=Docker --location=${LOCATION} --description="Demo Artifactory Repo"
```

Create a Docker container 

```bash
cat <<EOF >> Dockerfile
FROM gcr.io/google.com/cloudsdktool/google-cloud-cli:latest  
RUN pip install "jax[tpu]" -f https://storage.googleapis.com/jax-releases/libtpu_releases.html  
RUN pip install --upgrade clu  
RUN git clone https://github.com/google/flax.git  
RUN pip install --user -e flax  
WORKDIR ./flax/examples/mnist
EOF

docker build -t $IMAGE_NAME .
```

Tag the image and push it to the Artifactory Docker Repository 
```bash
docker tag $IMAGE_NAME ${LOCATION}-docker.pkg.dev/${PROJECT}/${REPO_NAME}/${IMAGE_NAME}:${TAG}
docker push ${LOCATION}-docker.pkg.dev/${PROJECT}/${REPO_NAME}/${IMAGE_NAME}:${TAG}
```

Create a script with your Cloud TPU job code, in this simple example we are  counting the number of cores in each worker an globally
```bash
cat <<EOF >> pod-train-docker.sh
#!/bin/bash -xe
export PROJECT=cloud-tpu-slurm-demo
export REPO_NAME=cloud-tpu-slurm-demo
export IMAGE_NAME=cloud-tpu-slurm-demo
export TAG=jax
export ZONE=europe-west4-a
export LOCATION=europe-west4

gcloud compute tpus tpu-vm ssh $SLURMD_NODENAME --zone ${ZONE} --worker=all \
        --command="sudo usermod -a -G docker $USER
        sudo gcloud auth configure-docker $LOCATION-docker.pkg.dev --quiet
        sudo docker pull ${LOCATION}-docker.pkg.dev/${PROJECT}/${REPO_NAME}/${IMAGE_NAME}:${TAG}
	sudo docker run -ti -d --privileged --net=host --name ${IMAGE_NAME} ${LOCATION}-docker.pkg.dev/${PROJECT}/${REPO_NAME}/${IMAGE_NAME}:${TAG}
        sudo docker exec --privileged ${IMAGE_NAME} python3 -c \
	\"import jax; \
	print('global device count:', jax.device_count()); \
	print('local device count:', jax.local_device_count()) \
	\""
EOF
```

Change permissions on the file
```
chmod a+x pod-train-docker.sh
```

Launch the Slurm job 

```
$ sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
v2_32*       up   infinite     10  idle~ g0-compute-0-[0-9]
v2_8         up   infinite     10  idle~ g0-compute-1-[0-9]

$ sbatch -N1 -p v2_32 pod-train-docker.sh

```

The output file of the training job will look something similar to this
```
cat slurm.6
......
Digest: sha256:9355ced353d0a899f5a831941dd154ad13d8c4317d5710c3f9df1d333be2c87c
Status: Downloaded newer image for europe-west4-docker.pkg.dev/cloud-tpu-slurm-demo/cloud-tpu-slurm-demo/cloud-tpu-slurm-demo:jax
europe-west4-docker.pkg.dev/cloud-tpu-slurm-demo/cloud-tpu-slurm-demo/cloud-tpu-slurm-demo:jax
b3bf75e75425b39da37ffc0e1472a588f04b22cd447ce9b9ae24ac356809526f
4cace519dcd4ca45c3ea5bbf27ecda847f19ce8e5e1aaf2779ba93c814b1c267
d2f2f374a90755c27aa8ab96a446d94f867a874be34cc2a61935ad4c3264cb8c
fd643d7ddcef86f42f03979f3ed26148471b468c587e5b3e07efda49c12a93d4
global device count: 32
local device count: 8
global device count: 32
local device count: 8
global device count: 32
local device count: 8
global device count: 32
local device count: 8
```

# Troubleshooting
Logs are located in `/var/log/slurm` on both the controller instance and the 
worker 0 TPU VM. `resume.log` shows errors from provisioning the TPU itself. 
If the TPU started but never became available to the Slurm job, check the syslog 
on the TPU VM:
```bash
# tpu name is the same as the node name in Slurm sinfo
cloudshell$ gcloud compute tpus tpu-vm ssh <tpu name> --zone=<tpu zone>
...
sudo journalctl -o cat -u google-startup-scripts -f
```
From there you can also check the slurmd log using `systemctl status slurmd` or the log file in `/var/log/slurm`.

# Additional customization

You can add additional customization in the tpu-image using the [external_install_slurm.sh](../foundry/scripts/custom.d/ external_install_slurm.py) script

```bash
cloudshell$ ls foundry/scripts/custom.d/external_install_slurm.sh
#!/bin/bash
echo custom script run
```

