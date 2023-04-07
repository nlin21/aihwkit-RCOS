# https://ibm-ai-hardware-center.github.io/AiMOS/index.html

## Step 1 - ssh to a landing pad node

    ssh your-id@node

ssh into one of the following:  
- blp01.ccni.rpi.edu
- blp02.ccni.rpi.edu
- blp03.ccni.rpi.edu
- blp04.ccni.rpi.edu

Enter PIC+Token and password when prompted<br/><br/>
 
## Step 2 - ssh to a front end node

    ssh [node] 

ssh into one of the following:
- dcsfen01
- dcsfen02
- nplfen01

For our purposes we will be using the npl node<br/><br/>

## Step 3 - proxy setup

    export http_proxy=http://proxy:8888  
    export https_proxy=$http_proxy

This is required for internet access (to download packages)<br/><br/>

## Step 4 - load AIHW Toolkit conda environment

    $ conda activate /gpfs/u/software/npl-conda/aihwkit_0.7.0

This is the recommended conda environment
