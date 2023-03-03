
## Step 1 - ssh to a landing pad node

ssh into one of the following:  

    $ ssh your-id@node

- blp01.ccni.rpi.edu
- blp02.ccni.rpi.edu
- blp03.ccni.rpi.edu
- blp04.ccni.rpi.edu<br>

enter PIC+Token and password<br><br>
 
## Step 2 - ssh to a front end node

- nplfen01<br><br>

## Step 3 - proxy setup
https://docs.cci.rpi.edu/landingpads/Proxy/  

    $ export http_proxy=http://proxy:8888  
    $ export https_proxy=$http_proxy

<br>

## Step 4 - load AIHW Toolkit conda environment

    $ conda activate /gpfs/u/software/npl-conda/aihwkit_0.7.0

<br>

## Step 5 - run

navigate to appropriate directory (aihwkit/examples/)  

    python 'example.py'
