# Changelog

All notable changes to this project will be documented in this file.

## \[6.3.1\]

- Add reserved property for nodeset_tpu
- update lustre repository url

## \[6.3.0\]

- Upgrade installed Slurm to 23.02.7
- Fix deprecation warning in google_secret_manager_secret.
- Fix TPU delete_node API return message.

## \[6.2.0\]

- Reverse logic in valid_placement_nodes
- Add slurm_gcp_plugin support.
- Add reservation affinity to nodesets via reservation_name option.
- Change TPU node conf based on tpu version instead of TPU model.
- Add support for TPUv4
- Upgrade installed Slurm to 23.02.5

## \[6.1.2\]

- Fix accelerator optimized machine type SMT handling.
- Prefix user visible errors with its source.
- Fix accelerator optimized machine type socket handling.
- Only compare config.yaml blob to cache file.
- Fix login nodes appearing as compute nodes in Slurm output.
- Add enable_debug_logging and extra_logging_flags to terraform.
- Only attempt static node resume when node is powered down.
- Fix CUDA on Ubuntu by installing CUDA via runfile alongside NVIDIA driver from
  signed repo.
- Fix conf generation issue on reconfiguration.

## \[6.1.1\]

- Fix suspend issue with TPU nodes
- Add TPU job example
- Changed slurm dependency from man2html to man2html-base and man2html-core to
  reduce image size
- Changed default docker image name to remove the OS reference

## \[6.1.0\]

- Add on_host_maintenance to packer module to support instances with GPUs.
- Fix retry of powering up static nodes on failure.
- Add support for H3 machines and enumerated multi-socket processors.
- Fix munge failing after manual reboot of node.
- \[Beta feature\] Added support for TPU-vm nodes.
- \[Beta feature\] Added support for TPU-vm multi-rank nodes.
- Add `ignore_prefer_validation` to SchedulerParameters in generated cloud.conf.
- Remove unaltered centos-7 image from actively published and supported images.
- Upgrade installed Slurm to 23.02.4.
- Fix CUDA install on Ubuntu 20.04.

## \[6.0.0\]

- Add slurm cluster management daemon
- Update default Slurm version to 23.02.2.
- Make `slurm_cluster` root module use terraform 1.3 and optional object fields.
- Reconfigure now is a service on the instances.
- Move from project metadata to GCS bucket to store cluster files.
- Factored out nodeset modules (regular, dynamic) from partition module.
- Replace `zone_policy_*` with `zones` in nodeset module.
- Replace `access_config` with `enable_public_ip` and `network_tier`.
- Add partition options `default`, `resume_timeout`, `suspend_time`,
  `suspend_timeout`.
- Increase `nodeset_name` length to 15 characters (from 7).
- Remove `partition_name` length limit.
- Add `bandwidth_tier` support to instance templates.
- Move `spot` preemptible support to instance template.
- Fix login template name not using `group_name` in name schema.
- Add `enable_login` to toggle creation of login node resources.
- Remove partition level startup-scripts and network mounts.
- Fix Ubuntu 20.04 NVIDIA install.
- Change partition level placement policy to nodeset level.
- Use `topology.conf` to prioritize nodes within nodesets.
- Remove debian-10 and vanilla rocky-linux-8 images from build process and
  support.
- Fix threads per core inference.
- Upgrade Slurm to 23.02.3

## \[5.7.4\]

- Set EOL of published centos-7 image to Aug 2023. If you need this image for
  longer, consider switching to hpc-centos-7, which will have support through
  Jan 2024.
- Allow metadata key `slurmd_feature` to initiate dynamic node setup.
- Fix dynamic nodes using cloud_dns instead of cloud_reg_addrs.
- Disable TreeWidth when dynamic nodes are configured.
- Fix dynamic nodes failing to download custom scripts.
- Fix slurmsync with only dynamic nodes in system.
- Fix NVIDIA driver install after kernel upgrade for rocky-linux-8.

## \[5.7.3\]

- Fix detecting gpus on certain machine types.
- Forward additional error information to node reason and salloc/srun.
- Fix warning on missing python library httplib2.
- Fix lustre support in images by installing the latest available client version
  for each OS.
- Change image name format to use Slurm-GCP version instead of the Slurm
  version. eg. slurm-gcp-5-7-hpc-centos-7
- Disable Lustre install for Debian 11 because it is currently incompatible. It
  wasn't working anyway.

## \[5.7.2\]

- Fix DefMemPerCPU on partitions that only contain dynamic nodes.
- Add hpc-rocky-linux-8 image build using
  cloud-hpc-image-public/hpc-rocky-linux-8 as a base.
- Update default slurm to 22.05.9

## \[5.7.1\]

- Fix regression in load_bq.py.
- Fix slurmsync.py handling of pub/sub subscriptions when enable_reconfigure.
- Add retries to munge mount to handle the case of attempted mount before the
  controller is ready.
- Fix partition generation with both nodes and feature.
- Fix regex parser for ops agent ingestion of slurm logs.
- Add wait on placement group creation to avoid race condition during resume.

## \[5.7.0\]

- Expose `cloud_logging_filter` output from controller modules.
- Add `partition_feature` for external dynamic nodes.
- Add setup.py --slurmd-feature option for external dynamic node startup.
- Installing signed nvidia drivers from repo added to ansible for Ubuntu 20.04
  only. This allows using GPUs on shielded VMs.
- Added legacy k80 support to ansible and made installing the latest nvidia the
  default. A k80-compatible image based on the hpc-centos-7 image family will
  now also be built.
- Packer module refactored to build only a single image at a time.
- Add HTC example terraform project.

## \[5.6.3\]

- Increase project metadata timeouts.
- Add cluster cloud logging filter output.
- Add Ubuntu 22.04 LTS support.
- Add preliminary ARM64 image support for T2A instances.
- Add Debian 11 support.
- Add Rocky Linux 8 support.
- Adjust logging for config not found.

## \[5.6.2\]

- Fix Terraform 1.2 incompatibility introduced in 5.6.1.

## \[5.6.1\]

- Fix Terraform 1.4.0 incompatibilities.
- `setup.log` now discoverable in GCP Cloud Logger.
- Job `admin_comment` contains last allocated node failure.
- Resume failures now notify srun of the error.
- startup-script - Add logging level prefixes for parsing.
- Fix slurm and slurm-gcp logs not showing up in Cloud Logging.
- resume.py - No longer validate machine_type with placement groups.
- Raise error from incorrect settings with dependent inputs.
- For gcsfuse network storage, server_ip can be null/None or "".
- Fix munge mount export from controller.
- Enable DebugFlags=Power by default
- Make slurmsync check preemptible status from instance rather than the
  template.

## \[5.6.0\]

- Add support for custom machine types.
- Add job id label for exclusive nodes.
- Add zone_target_shape to partitions, mapped to bulkInsert targetShape.
- Fix Lustre mounts failing because of failing to resolve server IP address.

## \[5.5.0\]

- Fix external network_storage being added to exportfs
- Fix supported instance family for placement groups
- Add support for c3 instance family for placement groups.
- Properly export job comment and admin comment to BigQuery.
- Slurm updated to 22.05.8

## \[5.4.1\]

- Use FQDN as default `slurm_control_addr`.
- Mounts use `slurm_control_addr`, if available, otherwise `slurm_control_host`.

## \[5.4.0\]

- Add `var.install_dir` to `module.slurm_controller_hybrid` to specify the
  intended directory where the files are to be installed.
- Add `var.slurm_control_host_port` to `module.slurm_controller_hybrid` to
  specify the port for slurmd to connect for configless setup.
- Add `var.munge_mount` to `module.slurm_controller_hybrid` to specify an
  external munge.key source.
- Fix unwanted mounting of login_network_storage on compute nodes.
- Add CI testsuite using gitlab CI.

## \[5.3.0\]

- Use configless mode for cluster configuration management.
- Hybrid - Write files with more restrictive permissions.
- Fix `module.slurm_cluster` not propagating `var.disable_default_mounts` to
  `module.slurm_controller_hybrid`.
- Fix creation of instances in placement groups.
- slurm_controller_hybrid - add `var.slurm_control_addr` option to allow a
  secondary address to be used.
- No longer create \*.conf.bak files.
- Upgrade Slurm to 22.05.6.
  - **WARNING:** Breaking change to terraform modules -- default image has
    changed.

## \[5.2.0\]

- `module.slurm_instance_template` - remove unused `var.bandwidth_tier`.
- Add support for `access_config` on partition compute nodes.
  - **WARNING:** Breaking change to `slurm_cluster`, `slurm_partition` modules
    -- new field `access_config`.
- Add support for configurable startup script timeout.
  - **WARNING:** Breaking change to `slurm_cluster`, `slurm_partition` modules
    -- new field `partition_startup_script_timeout`.
- Fix enable_cleanup_subscriptions defined but not used in certain examples.
- Fix `slurm_controller_hybrid` not respecting `disable_default_mounts`.
- Removed unused `slurm_depends_on` from modules.
- Fix scripts running without config.yaml.
- Reimplement backoff delay on retry attempts.
- Upgrade Slurm to 22.05.4.
  - **WARNING:** Breaking change to terraform modules -- default image has
    changed.
- Fix Nvidia ansible role install when kernel is updated.

## \[5.1.0\]

- Add support for gvnic and tier1 networking.
  - **WARNING:** Breaking change to `slurm_cluster`, `slurm_partition` modules
    -- new field `bandwidth_tier`.
- Fix get_insert_operations using empty filter item.
- Fix project id in wait_for_operation for resume.py from some hybrid setups.
- Add more useful error logging to resume.py
- Fix resume.py starting more than 1k identical nodes at a time.
- Ensure proper slurm ownership on instance template info cache.
- Honor `disable_smt=true` on compute instances.
- Improve logging and add logging flags to show API request details.
- Fix usage of slurm_control_host in config.yaml.
- Fix partition network storage.
- Improved speed of creating instances.
- In scripts, ignore GCP instances without Slurm-GCP metadata.
- Upgrade Slurm to 22.05.3.
- Pin lustre version to 2.12.

## \[5.0.3\]

- Allow configuring controller hostname for hybrid deployments.
- {resume|suspend}.py ignore nodes not in cloud configuration (config.yaml).
- Constrain packages in Pipfile and requirements.txt
- Allow hybrid scripts to succeed when slurm user does not exist.
- Fix pushing cluster config to project metadata in hybrid terraform
  deployments.
- Add disable_default_mounts option to terraform modules. This is needed for
  hybrid deployments.
- Ensure removal of placement groups on failed resume.
- Add retries and error logging to writing the template info cache file.
- Remove nonempty option from gcsfuse mounts. That option is no longer supported
  in fusermount3
- Restore lustre download url in ansible role. The url change was reverted.

## \[5.0.2\]

- Fix applying enable_bigquery_load to an existing cluster
- Fix setting resume/suspend_rate
- Do not set PrologSlurmctld and EpilogSlurmctld when no partitions have
  enable_job_exclusive.
- Change max size of placement group to 150.
- Allow a2 machine types in placement groups.
- Constrain length of variables that influence resource names.
- Add Slurm shell completion script to environment.
- Use Slurm service files compiled from source.
- Mitigate importlib.util failing on python > 3.8
- Add options to build lighter-weight images by disabling some ansible roles
  (eg. CUDA).
- Fix lustre rpm download url for image creation.
- Remove erroring and redundant package libpam-dev from debian image creation.
- Upgrade python library google-cloud-storage to ~2.0.
- Upgrade Slurm to 22.05.2.

## \[5.0.1\]

- Disable ConstrainSwapSpace in etc/cgroup.conf.tpl
- Remove leftover home dir after ansible provisioning of image.

## \[5.0.0\]

- Convert NEWS to CHANGELOG.md
- Create ansible roles from foundry build process.
- Add packer and ansible based image building process and configuration.
- Slurm scripts are baked into the image.
- Remove foundry based image building process.
- Create new Slurm terraform modules and examples, using
  [cloud-foundation-toolkit](https://cloud.google.com/foundation-toolkit) and
  best practices.
- Use terraform module to define Slurm partitions.
- Use instance templates to create Slurm instances.
- Support partitions with heterogeneous compute nodes.
- Rename partition module boolean options.
- Change how static and dynamic nodes are defined.
- Change how zone policy is defined in partition module.
- Store cluster Slurm configuration data in project metadata.
- Add top level terraform module for a Slurm cluster.
- Add pre-commit hooks for terraform validation, formatting, and documentation.
- Slurm cluster resources are labeled with slurm_cluster_id.
- All compute nodes are managed by the controller module.
- Update module option for toggling simultaneous multithreading (SMT).
- scripts - downgrade required python version to 3.6
- Add new hybrid management process using terraform Slurm modules.
- Rename metadata slurm_instance_type to slurm_instance_role.
- Add module option for cluster development mode.
- Change terraform minimum required version to 1.0
- Remove old terraform modules and examples.
- Add ansible role to install custom user scripts from directory.
- Change `*-custom-install` variable names and they can now accept multiple
  custom user scripts.
- Store cluster provisioning user scripts in project metadata.
- Unify partition option naming with configuration object.
- Add module option to toggle os-login based authentication.
- Add new module for creating Slurm cluster service accounts and IAM.
- Add new module for creating Slurm cluster firewall rules.
- Add pre-commit hooks for python linting and formatting.
- Add terraform examples to fully manage cluster deployment.
- Add terraform example for custom authentication using winbind.
- Change image naming template to prevent name collision with v4.
- Add job workflow helper script to submit and migrate job data.
- Harden secrets management (e.g. cloudsql, munge, jwt).
- Add module option for job level prolog and epilog user scripts.
- Add module option for partition level node configuration scripts.
- Add module option for partition line configuration.
- Add module option for node line configuration.
- Use Google ops-agent for cloud logging and monitoring.
- Add packer configuration option for user ansible roles.
- Add module option for job account data storage in BigQuery.
- Add module option to cleanup orphaned compute and placement group resources.
- Add module option to reconfigure the cluster when Slurm configurations change
  (e.g. slurm.conf, partition definitions).
- Add module option to cleanup orphaned subscription resources.
- Add pre-commit hooks for miscellaneous formatting and validation.
- Add pre-commit hooks for yaml formatting.
- Add Google services enable/check to examples.
- scripts - improve reporting of missing imported modules.
- Allow suspend.py to delete exclusive instances, which allows power_down_force
  to work on exclusive nodes.
- Add better error reporting in setup script for invalid machine types.
- Allow partial success in bulkInsert for resume.py
- Add bulkInsert operation failure detection and logging
- Force `enable_placement_groups=false` when `count_static > 0`.
- Add module variable `zone_policy_*` validation.
- Filter module variable `zone_policy_*` input with region.
- Change ansible to install cuda and nvidia from runfile
- Reimplement spot instance support.
- Rename `*_d` startup script variables to `*_startup_scripts`.
- Eliminate redundant `slurm_cluster_id`.
- Add additional validation slurm_cluster partitions.
- Remove need for gpu instance by packer
- Disable LDAP ansible role for Debian family
- Rename node count fields.
- Upgrade Slurm to version 21.08.8
- Add proper retry on mount attempts
- Add cluster_id and job_db_uuid fields to BQ table schema.
- Fix potential race condition in loading BQ job data.
- Remove deployment manager support.
- Update Nvidia to 470.82.01 and CUDA to 11.4.4
- Re-enable gcsfuse in ansible and workaround the repo gpg check problem

## \[4.1.5\]

- Fix partition-specific network storage from controller to compute nodes.
- Bump urllib3 from 1.26.4 to 1.26.5 in foundry.
- Bump ipython from 7.21.0 to 7.31.1 in foundry.

## \[4.1.4\]

- Updated Singularity download URL in custom-controller-install script.
- Fix static compute nodes being destroyed when `exclusive=true`
- Add CompleteWait to mitigate a race of latent operations from
  (Epilog|Prolog)Slurmctld from causing node failure on subsequent jobs.
- Fix calling "scontrol ... state=resume" in suspend.py for all nodes multiple
  times for exclusive jobs.

## \[4.1.3\]

- Add preliminary spot instance support (eg. preemptible_bursting = "spot").
- Regularly delete instances corresponding to Slurm nodes that should be powered
  down.
- Upgrade to Slurm 21.08.4.
- Pin Nvidia driver to 460.106.00-1.
- Pin Cuda to 11.2.2.
- Pin gcloud to 365.0.1-1 on centos images - workaround broken package.
- Enable swap cgroup control on debian images - fixes a Slurm compute node
  error.
- Add startup scripts as terraform vars.

## \[4.1.2\]

- setup.py - change LLN=yes to LLN=no

## \[4.1.1\]

- slurmsync.py - fix powering up nodes from being downed.

## \[4.1.0\]

- suspend.py - now handles "Quota exceeded" error
- Support for Intel-select options
- slurmrestd - changed user from root to user slurmrestd
- resume.py - fix state=down reason being malformed
- suspend.py - scontrol update now specifies new state=power_down_force
- slurm.conf - update to AccountingStoreFlags=job_comment
- slurmsync.py - state flags use new POWERED_DOWN state
- Updated Slurm to version 21.08.2

## \[4.0.4\]

- Configure sockets, cores, threads on compute nodes for better performance with
  `cons_tres`.

## \[4.0.3\]

- Introduce NEWS file
- Recommended image is now
  `schedmd-slurm-public/hpc-centos-7-schedmd-slurm-20-11-7`
- Changed slurmrestd port to 6842 (from 80)
- `partitions\[\].image_hyperthreads=false` now actively disables hyperthreads
  on hpc-centos-7 images, starting with the now recommended image
- `partitions\[\].image_hyperthreads` is now true in tfvars examples
- Fixed running of `custom-compute-install` on login node
- Fixed slurmrestd install on foundry debian images
- Disable SELinux (was permissive) to fix hpc-centos-7 reboot issue
- Updated Slurm to 20.11.7
