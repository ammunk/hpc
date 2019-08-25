#!/bin/bash

#SBATCH --account=rrg-kevinlb

# THIS SCRIPT IS CALLED OUTSIDE USING "sbatch"
# FOLLOWING ENV VARIABLES HAS TO BE PROVIDED:
#   - CMD
#   - CONTAINER
#   - BASERESULTSDIR
#   - OVERLAYDIR_CONTAINER
#   - STUFF_TO_TAR
#   - RESULTS_TO_TAR

module load singularity/3.2

# see eg. https://docs.computecanada.ca/wiki/A_tutorial_on_%27tar%27

# move data to temporary SLURM DIR which is much faster for I/O
echo "Copying singularity to ${SLURM_TMPDIR}"
time rsync -av "$CONTAINER" "$SLURM_TMPDIR"

if [ ! -z ${STUFF_TO_TAR+x} ]; then
    if [ ! -f "tar_ball_${STUFF_TO_TAR}.tar.gz"]; then
       time tar -cf "tar_ball_${STUFF_TO_TAR}.tar" $STUFF_TO_TAR
    fi
fi

# go to temporary directory
cd "$SLURM_TMPDIR"

if [ ! -z ${STUFF_TO_TAR+x} ]; then
    echo "Moving tarballs to slurm tmpdir"
    time tar -xf "${BASERESULTSDIR}/tar_ball_${STUFF_TO_TAR}.tar"
fi

DB="db_${SLURM_JOB_ID}"
OVERLAY="overlay_${SLURM_JOB_ID}"
TMP="tmp_${SLURM_JOB_ID}"

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

if [ ! -z ${RESULTS_TO_TAR+x} ]; then
    for file in "${RESULTS_TO_TAR}"; do
        mv file "file_${SLURM_JOB_ID}"
    done

    RESULTS_TO_TAR=( $RESULTS_TO_TAR )
    RESULTS_TO_TAR="${RESULTS_TO_TAR[@]}/%/_${SLURM_JOB_ID}"

else
    # IF NO RESULTS TO TAR IS SPECIFIED - MAKE A TARBALL OF THE ENTIRE RESULTS DIRECTORY
    RESULTS_TO_TAR="results"

# make a tarball of the results
time tar -cf "tar_ball_${RESULTS_TO_TAR}.tar" $RESULTS_TO_TAR

# move unpack the tarball to the BASERESULTSDIR
cd $BASERESULTSDIR
tar --keep-newer-files -xf "${SLURM_TMPDIR}/tar_ball${RESULTS_TO_TAR}.tar"
