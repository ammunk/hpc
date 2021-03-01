#!/bin/bash
## for torch distributed launch
nnodes=$1               # total number of nodes used in this computation
node_rank=$2            # current node rank, 0-indexed
nproc_per_node=$3       # number of processes (models) per node (typically equal number of gpus per node)
master_addr=$4          # hostname for the master node
tarball=$5              # tarball containing data etc to be moved to local node
port=8888               # port to use

cmd_base="python -m torch.distributed.launch --nproc_per_node ${nproc_per_node}"
cmd_base="${cmd_base} --nnodes ${nnodes} --node_rank ${node_rank} --master_addr"
cmd_base="${cmd_base} ${master_addr} --master_port ${port}"

program="$(cut -d ' ' -f1 <<< "${cmd}")"
if [[ ! ${program} == "python"* ]]; then
    echo "Command must be a python execution" >&2 ; exit 1
fi
cmds="$(cut -d ' ' -f2- <<< "${cmd}")"
cmd="${cmd_base} ${cmds}"
echo "COMMANDS GIVEN: ${cmd[@]}"
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
