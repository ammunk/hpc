#!/bin/bash

#SBATCH --account=rrg-kevinlb

# THIS SCRIPT IS CALLED OUTSIDE USING "sbatch"
# FOLLOWING ENV VARIABLES HAS TO BE PROVIDED:
#   - CMD
#   - CONTAINER
#   - BASERESULTSDIR
#   - RESULTSDIR_CONTAINER

cd $EXP_DIR

module load singularity cuda/10

LOCAL="${BASERESULTSDIR}/${EXP_NAME}_${SLURM_JOB_ID}"
MOUNT="${RESULTSDIR_CONTAINER}"
OVERLAY="${OVERLAYDIR}"

if [ ! -d "$LOCAL" ]; then
    mkdir "$LOCAL"
fi

# make directory that singularity can mount to and use to setup a database
# such as postgresql or a monogdb etc.
mkdir db

# make overlay directory, which may or may not be used
mkdir overlay

# --nv option: bind to system libraries (access to GPUS etc.)
# --no-home and --contain mimics the docker container behavior
# without those /home and more will be mounted be default
# using "run" executed the "runscript" specified by the "%runscript"
# any argument give "CMD" is passed to the runscript
singularity run \
            --nv \
            -B "${LOCAL}:${MOUNT}" \
            -B db:/db \
            -B overlay:"${OVERLAY}" \
            --no-home \
            --contain \
            "$CONTAINER" \
            "$CMD"
