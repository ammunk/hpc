#!/bin/bash

# THIS SCRIPT IS CALLED OUTSIDE USING "sbatch"
# FOLLOWING ENV VARIABLES HAS TO BE PROVIDED:
#   - CMD - command given to singularity
#   - CODE_DIR - directory where the singularity container/code is located
#   - CONTAINER - name of singularity container
#   - BASEDIR - must point to somewhere on **/scratch/
#   - WORKDIR_MOUNT - directory in the singularity container where code will be run
#   - RESULTS_MOUNT - directory in the singularity container where results will be saved
#   - STUFF_TO_TMP - e.g. move the training data to the SLURM_TMPDIR for traning a network
#   - RESULTS_TO_SCRATCH - the results we seek to move back from the temporary directory to a **/scratch location

# see - https://docs.computecanada.ca/wiki/Using_GPUs_with_Slurm for why we add this

if [[ "${BASEDIR}" == *"scratch"* ]]; then
    module load singularity/3.5

    # see eg. https://docs.computecanada.ca/wiki/A_tutorial_on_%27tar%27

    # move data to temporary SLURM DIR which is much faster for I/O
    echo "Copying singularity to ${SLURM_TMPDIR}"
    time rsync -av "${CODE_DIR}/${CONTAINER}" "${SLURM_TMPDIR}"

    # replace any "/"-character or spaces with "_" to use as a name
    stuff_to_tar_suffix=$(tr ' |/' '_' <<< ${STUFF_TO_TMP})

    if [ ! -z "${STUFF_TO_TMP}" ]; then
        if [ ! -f "tar_ball_${stuff_to_tar_suffix}.tar" ]; then
            # make tarball in $BASEDIR
            echo "Creating tarball"
            time tar -cf "tar_ball_${stuff_to_tar_suffix}.tar" $STUFF_TO_TMP
        fi
    fi

    # go to temporary directory
    cd "$SLURM_TMPDIR"

    if [ ! -z "${STUFF_TO_TMP}" ]; then
        echo "Moving tarball to slurm tmpdir"
        time tar --keep-newer-files -xf "${BASEDIR}/tar_ball_${stuff_to_tar_suffix}.tar"
    fi

    DB="db_${SLURM_JOB_ID}"
    OVERLAY="overlay_${SLURM_JOB_ID}"
    TMP="tmp_${SLURM_JOB_ID}"
    HOME_OVERLAY="home_overlay_${SLURM_JOB_ID}"

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

    if [ ! -d datasets ]; then
        mkdir datasets
    fi

    if [ ! -d "$HOME_OVERLAY" ]; then
        mkdir "$HOME_OVERLAY"
    fi

    echo "COMMANDS GIVEN: ${CMD}"
    echo "STUFF TO TMP: ${STUFF_TO_TMP}"
    echo "RESULTS TO TAR: ${RESULTS_TO_SCRATCH}"

    # --nv option: bind to system libraries (access to GPUS etc.)
    # --no-home and --containall mimics the docker container behavior
    # --cleanenv is crucial to get wandb to work, as local environment variables may cause it to break on some systems
    # without those /home and more will be mounted be default
    # using "run" executed the "runscript" specified by the "%runscript"
    # any argument give "CMD" is passed to the runscript
    SINGULARITYENV_SLURM_JOB_ID=$SLURM_JOB_ID \
        SINGULARITYENV_SLURM_PROCID=$SLURM_PROCID \
        SINGULARITYENV_WANDB_ENTITY="Muffiuz" \
        singularity run \
        --nv \
        --cleanenv \
        -B results:"${RESULTS_MOUNT}" \
        -B datasets:/datasets \
        -B "${DB}":/db \
        -B "${TMP}":/tmp \
        -B "${OVERLAY}":"${WORKDIR_MOUNT}" \
        -B "${HOME_OVERLAY}":"${HOME}" \
        --no-home \
        --contain\
        --writable-tmpfs \
        "$CONTAINER" \
        "$CMD"

    ######################################################################

    # Move results back (if RESULTS_TO_SCRATCH is set)

    # MAKE SURE THE RESULTS SAVED HAVE UNIQUE NAMES EITHER USING JOB ID AND
    # OR SOME OTHER WAY - !!!! OTHERWISE STUFF WILL BE OVERWRITTEN !!!!

    ######################################################################

    if  [ ! -z "${RESULTS_TO_SCRATCH}" ]; then
        # if variable is provided make into an array
        IFS=' ' read -a RESULTS_TO_SCRATCH <<< "${RESULTS_TO_SCRATCH[@]}"
        # replace any "/"-character or spaces with "_" to use as a name
        results_to_tar_suffix="$(tr ' |/' '_' <<< ${RESULTS_TO_SCRATCH[@]})"

        # make a tarball of the results
        time tar -cf "tar_ball_${results_to_tar_suffix}_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}.tar" "${RESULTS_TO_SCRATCH[@]}"

        # move unpack the tarball to the BASEDIR
        cd "${BASEDIR}/${EXP_NAME}"
        time tar --keep-newer-files -xf "${PLAI_TMPDIR}/tar_ball_${results_to_tar_suffix}_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}.tar"
    fi
else
    echo "BASEDIR does not point to anywhere on **/scratch" >&2; exit 1
fi
