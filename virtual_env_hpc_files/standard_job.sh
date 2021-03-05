#!/bin/bash
#
tarball="$1"
IFS=', ' read -r -a cmd <<< "${cmd}"
if [[ "${scratch_dir}" == *"scratch"* ]]; then
    # check if srun (and therefore scontrol etc) exists
    if ! srun -v COMMAND &> /dev/null
    then
        PATH=/opt/slurm/bin:${PATH}
    fi

    # create plai machine temporary directory
    if [[ "${SLURM_TMPDIR}" == *"scratch-ssd"* ]]; then
        SLURM_TMPDIR="${SLURM_TMPDIR}_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
        mkdir -p ${SLURM_TMPDIR}
    fi
    source ${source_dir}/virtual_env/bin/activate

    if [ ! -z "${tarball}"  ]; then
        # go to temporary directory
        echo "Moving ${tarball} to local node"
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
