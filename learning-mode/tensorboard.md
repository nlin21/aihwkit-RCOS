# Tensorboard Setup

Once the job has begun, a logs/fit/ directory will appear in the working directory. 

Within a conda environment, tensorboard can be started with:

    tensorboard --logdir /path/to/logs --host "0.0.0.0" --port 60000

Then, in a separate terminal:

    ssh -L60000:nplfen01:60000 <your-id>@blp01.ccni.rpi.edu

Now you can point your browser to http://localhost:60000
