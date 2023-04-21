# Instructions for our custom conda installation of aihwkit

## Prerequisites
https://ibm-ai-hardware-center.github.io/AiMOS/aimos-env-basics.html#initial-environment-setup
- passwordless is set up
- proxy is set up
- ssh'd into a front end node

<br/>

## Step 1 - Install the necessary dependencies

    conda install cmake openblas pybind11
    conda install -c conda-forge scikit-build
    conda install -c pytorch pytorch

<br/>

## Step 2 - Clone the aihwkit repository into scratch/ 

    git clone https://github.com/IBM/aihwkit.git

cd into the aihwkit folder

<br/>

## Step 3 - Build aihwkit
Install additional dependencies (there may be conflict errors but that's okay)

    pip install -r requirements.txt

Load modules and set up C compilers

    module load gcc/8.4.0/1
    module load cuda/11.2
    export CC=`which gcc`
    export CXX=`which g++`

Install Intel MKL library and setup CUDA

    conda install -c intel mkl mkl-devel mkl-static mkl-include
    export CMAKE_PREFIX_PATH=$CONDA_PREFIX
    export MKL_ROOT=$CONDA_PREFIX
    export CUDA_HOME=/usr/local/cuda-11.2

Run in-place build setup

    python setup.py build_ext -j16 -DRPU_DEBUG=OFF -DUSE_CUDA=ON -G "Unix Makefiles" -DRPU_BLAS=MKL --inplace

*** 

## How to check the GPU utilization

    nvidia-smi

## Examples how to specify the GPUs you need to use:
To use GPU with id 6:

    export CUDA_VISIBLE_DEVICES=6 

To use all the 0, 1, 2, and 3 GPUs:

    export CUDA_VISIBLE_DEVICES=0,1,2,3

<br/>

## Jobs can submitted with the Slurm job scheduler
Staging of jobs should be done in ~/scratch/

Example script:

    SBATCH -D /gpfs/u/home/AHWT/AHWT<user-name>/scratch
    SBATCH -o joboutput.%J
    SBATCH -e joberror.%J
    SBATCH --time=06:00:00
    SBATCH --gres=gpu:1
    SBATCH --gpus=1
