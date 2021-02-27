#!/bin/bash
## for torch distributed launch
nnodes=$1               # total number of nodes used in this computation
node_rank=$2            # current node rank, 0-indexed
nproc_per_node=$3       # number of processes (models) per node
master_addr=$4          # hostname for the master node
tarball=$5              # tarball containing data etc to be moved to local node
port=8888               # port to use

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

python -m torch.distributed.launch \
    --nproc_per_node ${nproc_per_node} \
    --nnodes ${nnodes} \
    --node_rank ${node_rank} \
    --master_addr ${master_addr} \
    --master_port ${port} \
    "${cmd[@]}"
