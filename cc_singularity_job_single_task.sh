#!/bin/bash

#SBATCH --account=rrg-kevinlb

# THIS SCRIPT IS CALLED OUTSIDE USING "sbatch"
# FOLLOWING ENV VARIABLES HAS TO BE PROVIDED:
#   - CMD
#   - CONTAINER
#   - BASERESULTSDIR
#   - OVERLAYDIR_CONTAINER
#   - STUFF_TO_TAR - e.g. move the training data to the SLURM_TMPDIR for traning a network
#   - RESULTS_TO_TAR - the results we seek to move back from the temporary file; e.g. if we train an inference network we don't need to also move the training data back again

# see - https://docs.computecanada.ca/wiki/Using_GPUs_with_Slurm for why we add this
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

module load singularity/3.2

# see eg. https://docs.computecanada.ca/wiki/A_tutorial_on_%27tar%27

# move data to temporary SLURM DIR which is much faster for I/O
echo "Copying singularity to ${SLURM_TMPDIR}"
time rsync -av "$CONTAINER" "$SLURM_TMPDIR"

# replace any "/"-character or spaces with "_" to use as a name
stuff_to_tar_suffix=$(tr ' |/' '_' <<< ${STUFF_TO_TAR})

if [ ! -z ${STUFF_TO_TAR} ]; then
    if [ ! -f "tar_ball_${stuff_to_tar_suffix}.tar" ]; then
        # make tarball in $BASERESULTSDIR
        echo "Creating tarball"
        time tar -cf "tar_ball_${stuff_to_tar_suffix}.tar" $STUFF_TO_TAR
    fi
fi

# go to temporary directory
cd "$SLURM_TMPDIR"

if [ ! -z ${STUFF_TO_TAR} ]; then
    echo "Moving tarball to slurm tmpdir"
    time tar -xf "${BASERESULTSDIR}/tar_ball_${stuff_to_tar_suffix}.tar"
fi

DB="db_${SLURM_JOB_ID}"
OVERLAY="overlay_${SLURM_JOB_ID}"
TMP="tmp_${SLURM_JOB_ID}"

# ensure resultsdir exists
if [ ! -d results ]; then
    mkdir results
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
echo $CMD
singularity run \
            --nv \
            -B "results:/results" \
            -B "${DB}":/db \
            -B "${TMP}":/tmp \
            -B "${OVERLAY}":"${OVERLAYDIR_CONTAINER}" \
            --no-home \
            --contain\
            --writable-tmpfs \
            "$CONTAINER" \
            "$CMD"

######################################################################

# MAKE SURE THE RESULTS SAVED HAVE UNIQUE NAMES EITHER USING JOB ID AND
# OR SOME OTHER WAY - !!!! OTHERWISE STUFF WILL BE OVERWRITEN !!!!

######################################################################

if [ -z ${RESULTS_TO_TAR} ]; then
    # IF NO RESULTS TO TAR IS SPECIFIED - MAKE A TARBALL OF THE ENTIRE RESULTS DIRECTORY
    RESULTS_TO_TAR=("results")
else
    # if variable is provided make into an array
    IFS=' ' read -a RESULTS_TO_TAR <<< $RESULTS_TO_TAR
fi

# replace any "/"-character or spaces with "_" to use as a name
results_to_tar_suffix=$(tr ' |/' '_' <<< ${RESULTS_TO_TAR[@]})

# make a tarball of the results
time tar -cf "tar_ball_${results_to_tar_suffix}_${SLURM_JOB_ID}.tar" ${RESULTS_TO_TAR[@]}

# move unpack the tarball to the BASERESULTSDIR
cd $BASERESULTSDIR
tar --keep-newer-files -xf "${SLURM_TMPDIR}/tar_ball_${results_to_tar_suffix}_${SLURM_JOB_ID}.tar"
