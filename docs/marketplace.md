# Google Cloud Marketplace

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=6 --minlevel=1 -->

- [Google Cloud Marketplace](#google-cloud-marketplace)
  - [Deploy](#deploy)
  - [Using the Cluster](#using-the-cluster)
  - [Destroy](#destroy)

<!-- mdformat-toc end -->

## Deploy

1. Go to the
   [SchedMD-Slurm-GCP](https://console.cloud.google.com/marketplace/product/schedmd-slurm-public/schedmd-slurm-gcp)
   listing in the GCP Marketplace. ![](../img/market-screen1.png)

1. Click “Launch”. ![](../img/market-screen2.png)

1. Some of the options provide defaults, others require input.

1. By default, one partition is enabled. Check the box “Enable partition” under
   the other “Slurm Compute Partition” sections to configure more partitions.

   ![](../img/market-screen3-2.png)

1. When complete, click “Deploy”.

   Your Slurm cluster is now deploying.

   ![](../img/market-screen4.png)

1. When the deployment is complete, you should see the following:

   ![](../img/market-screen5-1.png)

## Using the Cluster

1. SSH to the Login node by clicking the “SSH TO SLURM LOGIN NODE” button.

   ![](../img/market-screen5-2.png)

1. Provided are some recommended steps to verify the Slurm cluster is working as
   expected.

   - Summarize node status.

     ![](../img/market-screen6.png)

   - Submit a batch script job.

     ![](../img/market-screen7.png)

   - View the job queue.

     ![](../img/market-screen8.png)

   - View the new compute nodes added on the Console.

     ![](../img/market-screen9.png)

## Destroy

1. Go to [Deployment Manager](https://console.cloud.google.com/dm/deployments).

1. Select the Slurm cluster deployment from list.

1. Click "DELETE" and confirm action.

   > **WARNING:** Compute nodes are not cleaned up in "DELETE" action; compute
   > nodes must be manually destroyed.
