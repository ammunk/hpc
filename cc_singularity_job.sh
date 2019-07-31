#!/bin/bash

#SBATCH --account=rrg-kevinlb

# THIS SCRIPT IS CALLED OUTSIDE USING "sbatch"
# FOLLOWING ENV VARIABLES HAS TO BE PROVIDED:
#   - CMD
#   - CONTAINER
#   - BASERESULTSDIR
#   - RESULTSDIR_CONTAINER

module load singularity/3.2

LOCAL="${BASERESULTSDIR}/${EXP_NAME}"
MOUNT="${RESULTSDIR_CONTAINER}"
OVERLAY="${OVERLAYDIR_CONTAINER}"
DB="${BASERESULTSDIR}/db_${SLURM_JOB_ID}"
OVERLAY="${BASERESULTSDIR}/overlay_${SLURM_JOB_ID}"
TMP="${BASERESULTSDIR}/tmp_${SLURM_JOB_ID}"

if [ ! -d "$LOCAL" ]; then
    mkdir "$LOCAL"
fi

# make directory that singularity can mount to and use to setup a database
# such as postgresql or a monogdb etc.
if [ ! -d "$DB" ]; then
mkdir "$DB"
fi

# make overlay directory, which may or may not be used
if [ ! -d "$OVERLAY" ]; then
mkdir "$OVERLAY"
fi

# make tmp overlay directory otherwise /tmp in container will have very limited disk space
if [ ! -d "$TMP" ]; then
    mkdir "$TMP"
fi


# --nv option: bind to system libraries (access to GPUS etc.)
# --no-home and --contain mimics the docker container behavior
# without those /home and more will be mounted be default
# using "run" executed the "runscript" specified by the "%runscript"
# any argument give "CMD" is passed to the runscript
singularity run \
            --nv \
            -B "${LOCAL}:${MOUNT}" \
            -B "${DB}":/db \
            -B "${TMP}":/tmp \
            -B "${OVERLAY}":"${OVERLAYDIR_CONTAINER}" \
            --cleanenv \
            --no-home \
            --contain \
            --writable-tmpfs \
            "$CONTAINER" \
            "$CMD" > /dev/null

# remove temporary directories
rm -r "$OVERLAY" "$DB" "$TMP"
