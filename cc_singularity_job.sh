#!/bin/bash

#SBATCH --account=rrg-kevinlb

# THIS SCRIPT IS CALLED OUTSIDE USING "sbatch"
# FOLLOWING ENV VARIABLES HAS TO BE PROVIDED:
#   - CMD
#   - CONTAINER
#   - BASERESULTSDIR
#   - OVERLAYDIR_CONTAINER

module load singularity/3.2

# see eg. https://docs.computecanada.ca/wiki/A_tutorial_on_%27tar%27

if [ ! -f "${BASERESULTSDIR}/results.tar.gz" ]; then
   time tar -cf results.tar.gz results
fi

# move data to temporary SLURM DIR which is much faster for I/O
echo "Copying singularity to ${SLURM_TMPDIR}"
time rsync -av "$CONTAINER_NAME" "$SLURM_TMPDIR"
cd "$SLURM_TMPDIR"

echo "Moving tarball to slurm tmpdir"
time tar -xf ${BASERESULTSDIR}/results.tar.gz

DB="db_${SLURM_JOB_ID}"
OVERLAY="overlay_${SLURM_JOB_ID}"
TMP="tmp_${SLURM_JOB_ID}"

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
# --no-home and --containall mimics the docker container behavior
# without those /home and more will be mounted be default
# using "run" executed the "runscript" specified by the "%runscript"
# any argument give "CMD" is passed to the runscript
singularity run \
            --nv \
            -B "results:/results" \
            -B "${DB}":/db \
            -B "${TMP}":/tmp \
            -B "${OVERLAY}":"${OVERLAYDIR_CONTAINER}" \
            --cleanenv \
            --no-home \
            --containall \
            --writable-tmpfs \
            "$CONTAINER" \
            "$CMD"

# move results back to SCRATCH using rsync (to only add new stuff)
echo "Copying results back to scratch"
time tar -cf ${BASERESULTSDIR}/results.tar.gz results
# decompress
cd $BASERESULTSDIR
tar -xf ${BASERESULTSDIR}/results.tar.gz
