# Cloud Ops Agent Ansible Tutorial
This tutorial will provide you with a preconfigured environment for deploying the new unified [Cloud Ops Agent](https://github.com/GoogleCloudPlatform/google-cloud-ops-agents-ansible). Inside the custom cloudshell environment, Ansible is already installed with the necessary inventory and configuration files to get started. To learn more about Ansible visit [docs.ansible.com](https://docs.ansible.com)

## Prerequisites

**NOTE:** By default, this tutorial applies the Cloud Ops Agent to all hosts within a project which may incur additional costs. See [Define Your Playbook](#define-your-playbook) below to change that behavior.

#### In order to use Ansible and other configuration automation tools to install the Cloud Ops Agent you must:
1. Have a service account available for Ansible to query the inventory
2. Be able to ssh to the systems and have sufficient escalation privileges to install packages

If these items are not the case for your project, consider creating a new test project following one of the [GCE Tutorials](https://cloud.google.com/compute/docs/tutorials) and see [SSH connections to Linux VMs](https://cloud.google.com/compute/docs/instances/ssh) for additional details.

### Adding ssh keys
If you have an SSH key that works for the GCE instances in this project, you can upload it inside this ephemeral container via Cloud Editor by going to *File > Upload File*

## Service Account Setup 
Confirm you are logged in:
```bash
 gcloud auth list
 ```
If not, login to your gcp account within cloudshell, this ensures you're able to run the necessary commands
```bash
gcloud auth login
```

Set your project ID for the project you'd like to work within.  This project should have existing VMs available to run the Ansible playbook against:
Also set a service account ID that you wish to use when creating the service account for this project.
```bash
export PROJECT_ID="PROJECT_ID"
export SERVICE_ACCOUNT_ID="SERVICE_ACCOUNT_ID"
```

Continue by setting the project ID using the following gcloud command:
```bash
gcloud config set project $PROJECT_ID
```
Next you'll need to create a service account and credentials file. These resources allow configuration management tools to query and return the inventory from GCP dynamically. By using the `roles/compute.viewer` role, this credential can only view and compute resources and cannot modify any parts of the GCE system.
1. Create the service account.
```bash
gcloud iam service-accounts create $SERVICE_ACCOUNT_ID --description="Service account for ansible tutorial" --display-name="ansible-sa"
```
2. Create the iam policy binding and attach the necessary role to the account:
```bash 
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SERVICE_ACCOUNT_ID@$PROJECT_ID.iam.gserviceaccount.com" --role="roles/compute.viewer"
```
3. Create the key-file associated with the service account:
```bash
gcloud iam service-accounts keys create key-file --iam-account=$SERVICE_ACCOUNT_ID@$PROJECT_ID.iam.gserviceaccount.com
```

## Configure your environment
Set the following ENV variable so Ansible can find the key file:
```bash
export GCP_SERVICE_ACCOUNT_FILE=$PWD/key-file
```
Adjust the inventory file for the project you're using:
```bash
sed -i "s/ENTER_PROJECT_NAME/$PROJECT_ID/g" tutorial/inventory.gcp.yaml
```

Create an ssh agent to simplify repeated connections via ansible, and add the SSH key
```bash
ssh-agent
```
```bash
ssh-add PATH_TO_SSH_PUB_KEY
```

### Test your setup
Run this inventory command to confirm you can see your GCP hosts:
```bash
ansible-inventory all -i tutorial/inventory.gcp.yaml --list
```
And then run this to confirm you can successfully connect to your hosts before modifying them:
```bash
ansible all -m setup -i tutorial/inventory.gcp.yaml
```

If these commands return OK, you're ready to proceed!

## Running the Cloud Ops Agent Role
### Install the Cloud Ops Agent Ansible Role

Install the Ansible role:
```bash
ansible-galaxy install git+https://github.com/GoogleCloudPlatform/google-cloud-ops-agents-ansible.git
```

### Define Your Playbook

A simple Ansible playbook, `tutorial/example_playbook.yaml`:
```yaml
---
- name: Add Cloud Ops Agent to hosts
  hosts: all
  become: true
  roles:
    - role: google-cloud-ops-agents-ansible
      vars:
        agent_type: ops-agent
```
This playbook will target all hosts available to the inventory script, and will enable both logging and monitoring for the agent. You can change this by changing the host value to a specific group or system as you see fit.

For more variables see the [role's variable documentation](https://github.com/GoogleCloudPlatform/google-cloud-ops-agents-ansible#role-variables)

### Run the playbook

To execute the playbook, from your Cloud Terminal you can run:
```bash
ansible-playbook tutorial/example_playbook.yaml -i tutorial/inventory.gcp.yaml --user SSH_USER
```
**Tip** Be sure to specify the `--user` with the username associated with the ssh key.

## Conclusion

If the playbook completes successfully, your instances should now have the Cloud Ops Agent installed! You can check out their metrics and logs from the new Observability page for each GCE instance. 

### Cleanup

You may want to clean-up the items used during this tutorial including:
* Disabling the Cloud Ops Agent by setting each roles `package_state` variable to `absent` and running the playbook again.
* Deleting the [Service Account key](https://cloud.google.com/iam/docs/creating-managing-service-account-keys#deleting_service_account_keys) if this was created as a one time use.
* Deleting the [Service Account](https://cloud.google.com/iam/docs/creating-managing-service-accounts#deleting) if this was created as a one time use.