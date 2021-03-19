# Google Cloud Marketplace 

## Deploying

1. Go to the SchedMD-Slurm-GCP listing in the GCP Marketplace.  [SchedMD-Slurm-GCP Marketplace](https://console.cloud.google.com/marketplace/product/schedmd-slurm-public/schedmd-slurm-gcp)
<br>

![](./img/market-screen1.png)  

<br>
2. Click “Launch”.    


![](./img/market-screen2.png)  

***
3. Some of the options provide defaults, others require input.  

4. By default, one partition is enabled. Check the box “Enable partition” under the other “Slurm Compute Partition” sections to configure more partitions.  

![](./img/market-screen3-2.png)
***
5. When complete, click “Deploy”.

Your Slurm cluster is now deploying.

![](./img/market-screen4.png)
***
## Using the Cluster

When the deployment is complete, you should see the following:

![](./img/market-screen5-1.png)
***
1. SSH to the Login node by clicking the “SSH TO SLURM LOGIN NODE” button.

![](./img/market-screen5-2.png)
***
2. Provided are some recommended steps to verify the Slurm cluster is working as expected.
   
   * Summarize node status.

   ![](./img/market-screen6.png) 

   * Submit a batch script job.

   ![](./img/market-screen7.png)

   * View the job queue.

   ![](./img/market-screen8.png)
   
   * View the new compute nodes added on the Console.
   
   ![](./img/market-screen9.png)

