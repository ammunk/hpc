#!/bin/bash
## for torch distributed launch
nnodes=$1               # total number of nodes used in this computation
nproc_per_node=$2       # number of processes (models) per node
tarball=$3              # tarball containing data etc to be moved to local node

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

python -m tridensity.main \
    --seed ${seed} \
    --num_workers 6 \
    --max_iterations 1000 \
    --max_epochs 1000 \
    --experiment "toy" \
    --adv_lr 1e-5 \
    --gen_lr 1e-4 \
    --checkpoint_dir ${scratch_dir}/${exp_name}/checkpoints \
    --checkpoint_every 1000 \
    --visualize_every 500 \
    --log_every 100 \
    --batch_size ${batch_size} \
    --data_dir ${SLURM_TMPDIR}/datasets \
    distributed_lightning \
    --precision ${precision} \
    --num_nodes ${nnodes} \
    --gpus ${nproc_per_node}
