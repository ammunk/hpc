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

# see eg. https://docs.computecanada.ca/wiki/A_tutorial_on_%27tar%27

if [[ "${BASEDIR}" == *"scratch"* ]]; then
    PLAI_TMPDIR="/scratch-ssd/amunk_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"

    mkdir -p $PLAI_TMPDIR

    DB="db_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
    WORKDIR_OVERLAY="overlay_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
    TMP="tmp_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
    HOME_OVERLAY="home_overlay_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"

    cd "$BASEDIR"

    # move data to temporary SLURM DIR which is much faster for I/O
    echo "Copying singularity (${CODE_DIR}/${CONTAINER}) to ${PLAI_TMPDIR}"
    time rsync -av "${CODE_DIR}/${CONTAINER}" "${PLAI_TMPDIR}"
    time rsync -av "${CODE_DIR}/hpc_files/continue_jobs_commands.txt" "${PLAI_TMPDIR}"

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
    cd "$PLAI_TMPDIR"

    if [ ! -z "${STUFF_TO_TMP}" ]; then
        echo "Moving tarball to slurm tmpdir"
        time tar --keep-newer-files -xf "${BASEDIR}/tar_ball_${stuff_to_tar_suffix}.tar"
    fi

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
    if [ ! -d "$WORKDIR_OVERLAY" ]; then
        mkdir "$WORKDIR_OVERLAY"
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

    CMD=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "continue_jobs_commands.txt")
    echo "COMMANDS GIVEN: ${CMD}"
    echo "STUFF TO TMP: ${STUFF_TO_TMP}"
    echo "RESULTS TO TAR: ${RESULTS_TO_TAR}"

    # --nv option: bind to system libraries (access to GPUS etc.)
    # --no-home and --containall mimics the docker container behavior
    # --cleanenv is crucial to get wandb to work, as local environment variables may cause it to break on some systems
    # without those /home and more will be mounted be default
    # using "run" executed the "runscript" specified by the "%runscript"
    # any argument give "CMD" is passed to the runscript
    SINGULARITYENV_SLURM_JOB_ID=$SLURM_JOB_ID \
        SINGULARITYENV_SLURM_PROCID=$SLURM_PROCID \
        SINGULARITYENV_SLURM_ARRAY_JOB_ID=$SLURM_ARRAY_JOB_ID \
        SINGULARITYENV_SLURM_ARRAY_TASK_ID=$SLURM_ARRAY_TASK_ID \
        SINGULARITYENV_WANDB_ENTITY="Muffiuz" \
        /opt/singularity/bin/singularity run \
        --nv \
        --cleanenv \
        -B results:"${RESULTS_MOUNT}" \
        -B datasets:/datasets \
        -B "${HOME_OVERLAY}":"${HOME}" \
        -B ${DB}:/db \
        -B ${TMP}:/tmp \
        -B ${WORKDIR_OVERLAY}:${WORKDIR_MOUNT} \
        --no-home \
        --contain \
        --writable-tmpfs \
        ${CONTAINER} \
        ${CMD}

    ######################################################################

    # CLEANUP

    # remove temporary directories
    rm -rf "${PLAI_TMPDIR}"
    echo "CHECK WHATS IN /scratch-ssd:" && ls /scratch-ssd
else
    echo "BASEDIR does not point to anywhere on **/scratch" >&2; exit 1
fi
