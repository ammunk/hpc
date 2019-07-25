#!/bin/bash

#SBATCH --account=rrg-kevinlb

# THIS SCRIPT IS CALLED OUTSIDE USING "sbatch"
# FOLLOWING ENV VARIABLES HAS TO BE PROVIDED:
#   - CMD
#   - CONTAINER
#   - BASERESULTSDIR
#   - RESULTSDIR_CONTAINER

cd $EXP_DIR

module load singularity

LOCAL="${BASERESULTSDIR}/${EXP_NAME}_${SLURM_JOB_ID}"
MOUNT="${RESULTSDIR_CONTAINER}"

if [ ! -d "$LOCAL" ]; then
    mkdir "$LOCAL"
fi

# make directory that singularity can mount to and use to setup a database
# such as postgresql or a monogdb etc.
mkdir db

# --nv option: bind to system libraries (access to GPUS etc.)
# --no-home and --contain mimics the docker container behavior
# without those /home and more will be mounted be default
# using "run" executed the "runscript" specified by the "%runscript"
# any argument give "CMD" is passed to the runscript
singularity run \
            --nv \
            -B "${LOCAL}:${MOUNT}" \
            -B db:/db \
            --no-home \
            --contain \
            "$CONTAINER" \
            "$CMD"
