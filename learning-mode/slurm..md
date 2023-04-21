# Interactive Jobs with the Slurm Resource Manager

## Step 1
ssh into a front end node  

<br/>

## Step 2
Use the 'salloc' command to request for resources

    salloc -N [# of nodes] --gres==gpu:[# of GPUs] -t [time limit in minutes]

For the DCS cluster, the number of GPUs can range from 1-6.  
For the NPL cluster, the number of GPUs can range from 1-8.  
  
This will place the request into a queue, and will notify you when the node is available.

<br/>

## Step 3
ssh into the node when it is available  
Now you are able to run jobs with powerful computational resources.



