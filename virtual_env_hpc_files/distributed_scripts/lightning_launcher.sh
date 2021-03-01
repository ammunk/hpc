#!/bin/bash
## for torch distributed launch
nnodes=$1               # total number of nodes used in this computation
nproc_per_node=$2       # number of processes (models) per node (typically equal number of gpus per node)
tarball=$3              # tarball containing data etc to be moved to local node

# cleanup specified command
program="$(cut -d ' ' -f1 <<< "${cmd}")"
if [[ ! ${program} == "python"* ]]; then
    echo "Command must be a python execution" >&2 ; exit 1
fi
cmds="$(cut -d ' ' -f2- <<< "${cmd}" | sed -e 's/ .*num_nodes.* / /g' -e 's/ .*gpus.* / /g')"
cmds="$(sed -r  sed -e 's/ .*num_nodes.*//g' -e 's/ .*gpus.*//g' <<< "${cmds}")"
cmd="python ${cmds} --num_nodes=${nnodes} --gpus=${nproc_per_node}"
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

"${cmd[@]}"
