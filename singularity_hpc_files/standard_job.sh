#!/bin/bash

tarball="$1"
workdir="$2"

if [[ "${scratch_dir}" == *"scratch"* ]]; then

    if [[ "${SLURM_TMPDIR}" == *"scratch-ssd"* ]]; then
        SLURM_TMPDIR="${SLURM_TMPDIR}_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
        mkdir -p "${SLURM_TMPDIR}"
    fi

    if [[ ! "${SLURM_TMPDIR}" == *"scratch-ssd"* ]]; then
        module load singularity/3.5
    else
        PATH=/opt/singularity/bin:${PATH}
    fi

    echo "Copying singularity to ${SLURM_TMPDIR}"
    cd ${source_dir}
    time rsync -av "${container_path}" "${SLURM_TMPDIR}"

    if [ ! -z "${tarball}"  ]; then
        # go to temporary directory
        echo "Moving ${tarball} to local node"
        time tar -xf "${tarball}" \
            -C ${SLURM_TMPDIR} --strip-components=$(wc -w <<< $(tr "/" " " <<< ${scratch_dir}))
    fi

    DB="db_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
    WORKDIR_OVERLAY="overlay_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
    TMP="tmp_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
    HOME_OVERLAY="home_overlay_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"

    scratch_storage="${scratch_dir}/${exp_name}/singularity_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
    if [ ! -d "$RESULTSDIR" ]; then
        mkdir -p "$RESULTSDIR"
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

    if [ ! -d data ]; then
        mkdir data
    fi

    if [ ! -d "$HOME_OVERLAY" ]; then
        mkdir "$HOME_OVERLAY"
    fi

    if [ -z "${workdir}" ]; then
        # if wirkdir is empty make a dummy workdir that is unlikely to clash with anything inside the container
        workdir="/workdir_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
    fi

    # --nv option: bind to system libraries (access to GPUS etc.)
    # --no-home and --containall mimics the docker container behavior
    # --cleanenv is crucial to get wandb to work, as local environment variables may cause it to break on some systems
    # without those /home and more will be mounted be default.
    # Using "run" will execute the "runscript" specified by the "%runscript"
    SINGULARITYENV_SLURM_JOB_ID=$SLURM_JOB_ID \
        SINGULARITYENV_SLURM_PROCID=$SLURM_PROCID \
        SINGULARITYENV_SLURM_ARRAY_JOB_ID=$SLURM_ARRAY_JOB_ID \
        SINGULARITYENV_SLURM_ARRAY_TASK_ID=$SLURM_ARRAY_TASK_ID \
        SINGULARITYENV_WANDB_API_KEY=$WANDB_API_KEY \
        singularity run \
        --nv \
        --cleanenv \
        -B "${scratch_storage}":/scratch_storage \
        -B data:/data \
        -B "${HOME_OVERLAY}":"${HOME}" \
        -B "${DB}":/db \
        -B "${TMP}":/tmp \
        -B "${WORKDIR_OVERLAY}":"${workdir}" \
        --no-home \
        --contain\
        --writable-tmpfs \
        "${singularity_container}" \
        "$cmd"

    if [[ "${SLURM_TMPDIR}" == *"scratch-ssd"* ]]; then
        srun rm -r ${SLURM_TMPDIR}
    fi

else
    echo "scratch_dir does not point to anywhere on **/scratch" >&2; exit 1
fi
