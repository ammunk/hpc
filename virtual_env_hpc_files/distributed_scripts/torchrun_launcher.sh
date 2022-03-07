#!/bin/bash
node_rank=$1            # current node rank, 0-indexed
nproc_per_node=$2       # number of processes (models) per node (typically equal number of gpus per node)
master_addr=$3          # hostname for the master node
master_port=$4          # master port
tarball=$5              # tarball containing data etc to be moved to local node

export NCCL_BLOCKING_WAIT=1  #Set this environment variable if you wish to use the NCCL backend for inter-GPU communication.
nnodes=${SLURM_JOB_NUM_NODES}
cmd_base="torchrun --nproc_per_node ${nproc_per_node}"
cmd_base="${cmd_base} --nnodes ${nnodes}"

if (( $nnodes == 1 )); then
    cmd_base="${cmd_base} --standalone"
else
    cmd_base="${cmd_base} --rdzv_id=${SLURM_JOB_ID}"
    cmd_base="${cmd_base} --rdzv_backend=c10d"
    cmd_base="${cmd_base} --rdzv_endpoint=${master_addr}:${master_port}"
    cmd_base="${cmd_base} --max_restarts=3"
fi

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

if [ ! -z "${tarball}"  ]; then
    # go to temporary directory
    echo "Moving ${tarball} to local node"
    time tar -xf "${tarball}" \
        -C ${SLURM_TMPDIR} --strip-components=$(wc -w <<< $(tr "/" " " <<< ${scratch_dir}))
fi

"${cmd[@]}"
