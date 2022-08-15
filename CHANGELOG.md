# Changelog

All notable changes to this project will be documented in this file.

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
- Reenable gcsfuse in ansible and workaround the repo gpg check problem

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

- Configure sockets, cores, threads on compute nodes for better performace with
  `cons_tres`.

## \[4.0.3\]

- Introduce NEWS file
- Recommended image is now
  `schedmd-slurm-public/hpc-centos-7-schedmd-slurm-20-11-7`
- Changed slurmrestd port to 6842 (from 80)
- `partitions\[\].image_hyperthreads=false` now actively disables hyperthreads
  on hpc-centos-7 images, starting with the now recommended image
- `partitions\[\].image_hyperthreads` is now true in tfvars examples
- Fixed running of \`custom-compute-install on login node
- Fixed slurmrestd install on foundry debian images
- Disable SELinux (was permissive) to fix hpc-centos-7 reboot issue
- Updated Slurm to 20.11.07
