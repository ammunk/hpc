#!/usr/bin/env bash

tarball="$1"
IFS=', ' read -r -a cmd <<< "$2"
if [[ "${scratch_dir}" == *"scratch"* ]]; then

    # create plai machine temporary directory
    if [[ "${SLURM_TMPDIR}" == *"scratch-ssd"* ]]; then
        mkdir -p ${SLURM_TMPDIR}
    fi
    source ${source_dir}/virtual_env/bin/activate

    if [ ! -z ${tarball} ]; then
        # go to temporary directory
        time tar -xf "${tarball}" \
            -C ${SLURM_TMPDIR} --strip-components=$(wc -w <<< $(tr "/" " " <<< ${scratch_dir}))
    fi

    cd ${source_dir}
    echo "COMMANDS GIVEN: ${cmd[@]}"
    "${cmd[@]}"
    if [[ "${SLURM_TMPDIR}" == *"scratch-ssd"* ]]; then
        srun rm -r ${SLURM_TMPDIR}
    fi
else
    echo "scratch_dir does not point to anywhere on **/scratch" >&2; exit 1
fi
