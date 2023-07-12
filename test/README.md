The tests are written with pytest, with terraform handled by the python library
tftest. It is run from the `test` directory as

`pytest -vs --project_id=<test project> --cluster_name=<test cluster> --image-project=<image project> --image-family=<image family> --image=<image name>`

The Pipfile shows the dependencies. Only one of `--image-family` and `--image`
needs to be specified. The env var `GOOGLE_APPLICATION_CREDENTIALS` should be
set to a json file containing service account credentials. A private key
authorized to the GCP/service account should be in a file `test/gcp_login_id` or
in an env var `GCP_LOGIN_ID`.

pytest will create a cluster and run the following tests on it.

## Tests

Lines with \[ \] are not currently implemented but are planned.

test_config.py

- test_gpu_config
  - Check that the number of GPUs requested on nodes in terraform is equal to
    the number of Slurm gres:gpu configured.
- test_ops_agent
  - Check all running instances in the cluster for active ops agent fluentd
    service.
- test_controller_custom_scripts
  - check that the configured startup script ran
- test_login_custom_scripts
  - check that the configured login startup script ran
- \[ \] Network Storage Testing
  - Test that Lustre, NFS, and GCSFuse install and can mount storage correctly
    on the latest OS image, and/or the HPC image as available.
- \[ \] Reconfigure - did the slurm.conf change?

test_jobs.py

- test_job
  - Verify that a simple 3-node job running `srun hostname` completes
    successfully.
- test_gpu_job
  - On every partition with a GPU, run an sbatch `srun nvidia-smi` job and
    verify that the job completes successfully.
- test_shielded
  - On every partition with nodes configured for shielded VMs, run a simple job.
  - If the partition has a GPU _and_ the image OS is Ubuntu 20.04, run a GPU job
    instead.
    - skip shielded GPU partitions otherwise to avoid spinning up a GPU instance
      needlessly.
- test_openmpi
  - Run a simple 3-node MPI job and verify that it completes successfully.
- test_placement_groups
  - \[ \] start a 1-node job and verify it does _not_ get a placement group
  - On any placement group partitions,
    1. start a 10 minute 2-node job
    1. wait for the instances to start and the job to begin
    1. check the instances in the job for `resouceStatus.physicalHost` (topology
       information)
    - Make sure at least one one part of the topology tag matches between all
      instances
    4. cancel the job
    1. wait for the node to finish being powered down again
- test_preemption
  - on partitions with preemptible nodes
    1. start a long job
    1. wait for the job to start running
    1. stop an instance in the job allocation
    1. verify that the node goes down with reason set
    1. wait for the node to return to idle (slurmsync handles this)
    ###### TODO check that the job was requeued?
    6. cancel the job
- test_prolog_scripts
  - run a job and check that prolog and epilog scripts ran
- \[ \] test exclusive nodes
  - Since placement group nodes are also exclusive, this is being tested. But a
    test just for exclusive nodes would be good.
  - job runs on node
  - node is torn down after job
- \[ \] Regional placement
  - create 3 partitions that force direct jobs to different regions
  - submit job to each partition and verify region
  - verify that nodes get deleted after job is done.

test_nodes.py

- test_static
  - get the list of static nodes in the cluster and wait for them all to be
    powered up and idle
- test_compute_startup_scripts
  - Check that the custom compute startup script ran on the static nodes
- test_exclusive_labels
  - run job on exclusive nodes and check the instances for the correct job ID
    label
- \[ \] Catching leaked nodes
  - Tear down cluster while nodes are still provisioned, verify all nodes get
    torn down
  - Start up node outside of a job - verify slurmsync brings it down
