#!/bin/bash

#SBATCH --job-name=clay-laucher
#SBATCH --nodes=24
#SBATCH --ntasks-per-node=8          # EDIT if it's not 8-gpus per node
#SBATCH --cpus-per-task=12           # EDIT this to how many cpu cores the node has divided by num of gpus
#SBATCH --gres=gpu:8                 # EDIT this if it's not 8-gpus per node
#SBATCH --time=0-00:00:00            # EDIT the desired runtime
#SBATCH --exclusive
#SBATCH --partition=gpu      # EDIT to the desired partition name
#SBATCH --nodelist=gpu-dy-g6-[1-12],gpu-dy-g5-[1-12]
#SBATCH --output=%x-%j-%N.out

echo "START TIME: $(date)"

# auto-fail on any errors in this script
set -eo pipefail

# logging script's variables/commands for future debug needs
set -x

# EDIT the conda evn and any startup scripts
# source /path/to/start-xxx-user # if you have something to preload before the job
# Load any required modules (environments, libraries etc.)
eval "$(conda 'shell.bash' 'hook' 2> /dev/null)"

# initialize conda
conda activate /home/ubuntu/claymodel      # if you have conda env to activate

LOG_PATH="main_log.txt"

# PTL doesn't need a special launcher
LAUNCHER="python -u"

# Capture the number of nodes allocated by Slurm
NUM_NODES=$SLURM_JOB_NUM_NODES

# EDIT the path+name of the python script and whatever args it needs
PROGRAM="trainer.py fit --config configs/config.yaml --trainer.num_nodes=$NUM_NODES"

export CMD="$LAUNCHER $PROGRAM"

echo $CMD

# EDIT if you want to redirect /tmp to /scratch (some local SSD path) since /tmp is tiny on compute nodes
# export TMPDIR=/scratch

# EDIT: useful for debug if needed
#
# to debug NCCL issues
# export NCCL_DEBUG=INFO
#
# to unravel async errors w/o the correct traceback - potentially makes everything very slower
# export CUDA_LAUNCH_BLOCKING=1
#
# to force crashing on nccl issues like hanging broadcast
# export NCCL_ASYNC_ERROR_HANDLING=1

# srun error handling:
# --wait=60: wait 60 sec after the first task terminates before terminating all remaining tasks
# --kill-on-bad-exit=1: terminate a step if any task exits with a non-zero exit code
SRUN_ARGS=" \
    --wait=60 \
    --kill-on-bad-exit=1 \
    --jobid $SLURM_JOB_ID \
    "

# bash -c is needed for the delayed interpolation of env vars to work
srun $SRUN_ARGS bash -c "$CMD" 2>&1 | tee -a $LOG_PATH

echo "END TIME: $(date)"
