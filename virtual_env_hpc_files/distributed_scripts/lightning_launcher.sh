#!/bin/bash
## for torch distributed launch
nnodes=$1               # total number of nodes used in this computation
nproc_per_node=$2       # number of processes (models) per node
tarball=$3              # tarball containing data etc to be moved to local node

IFS=', ' read -r -a cmd <<< "${cmd}"
# create plai machine temporary directory
if [[ "${SLURM_TMPDIR}" == *"scratch-ssd"* ]]; then
    mkdir -p ${SLURM_TMPDIR}
fi

if [ ! -z ${tarball}  ]; then
    # go to temporary directory
    time tar -xf "${tarball}" \
        -C ${SLURM_TMPDIR} --strip-components=$(wc -w <<< $(tr "/" " " <<< ${scratch_dir}))
fi

batch_size=32 # batch size for each processes
precision=16 # set floating point precision

python "${cmd[@]}"
