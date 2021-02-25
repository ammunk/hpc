#!/bin/bash
## for torch distributed launch
nnodes=$1               # total number of nodes used in this computation
node_rank=$2            # current node rank, 0-indexed
nproc_per_node=$3       # number of processes (models) per node
master_addr=$4          # hostname for the master node
seed=$5                 # seed to be set for all processes
tarball=$6              # tarball containing data etc to be moved to local node
port=8888               # port to use

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
    -m tridensity.main \
    --seed ${seed} \
    --data_dir ${SLURM_TMPDIR}/datasets \
    --num_workers 6 \
    --experiment "toy" \
    --max_iterations 1000 \
    --max_epochs 1000 \
    --adv_lr 1e-5 \
    --gen_lr 1e-4 \
    --checkpoint_dir ${scratch_dir}/${EXP_NAME}/checkpoints \
    --checkpoint_every 1000 \
    --visualize_every 200 \
    --log_every 100 \
    --batch_size ${batch_size} \
    distributed_script \
    --local_world_size ${nproc_per_node}
