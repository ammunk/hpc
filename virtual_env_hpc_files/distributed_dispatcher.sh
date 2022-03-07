#!/bin/bash

tarball="$1"
if [[ -v CUDA_VISIBLE_DEVICES ]]
then
    gpus_per_node=$(echo $CUDA_VISIBLE_DEVICES | awk -F "," '{print NF}')
else
    gpus_per_node=$(nvidia-smi --list-gpus | wc -l)
fi

cd ${source_dir}
source virtual_env/bin/activate

if [[ "${SLURM_TMPDIR}" == *"scratch-ssd"* ]]; then
  SLURM_TMPDIR="${SLURM_TMPDIR}_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
fi

nodes=(`scontrol show hostname $SLURM_NODELIST`)
export MASTER_ADDR=$(hostname)
export MASTER_PORT=2345
num_nodes=${#nodes[@]}
scripts_dir="${source_dir}/hpc_files/virtual_env_hpc_files/distributed_scripts"
if [[ ${which_distributed} == "script" ]]; then
  for i in `seq 0 $(echo $num_nodes -1 | bc)`;
  do
      # each srun will consume all resources per node unless we explicitly
      # specify otherwise. This is fine since we only call srun once for each node
      echo "launching ${i} job on ${nodes[i]} with master address ${MASTER_ADDR} with ${gpus_per_node} allocated gpus"
      srun -w ${nodes[$i]} -N 1 -n 1 \
        bash ${scripts_dir}/script_launcher.sh \
        ${i} ${gpus_per_node} ${MASTER_ADDR} ${MASTER_PORT} ${tarball} &
  done
  wait
elif [[ ${which_distributed} == "lightning" ]]; then
  # srun consumes all resources which is intended as we do not manually call
  # srun per task. Rather srun creates n tasks.
  srun bash ${scripts_dir}/lightning_launcher.sh ${num_nodes} ${gpus_per_node} ${tarball}
else
    echo "Distributed specification not supported" >&2; exit 1
fi

echo "FINISHED DISTRIBUTED JOB"
echo "========================"

if [[ "${SLURM_TMPDIR}" == *"scratch-ssd"* ]]; then
  srun rm -r ${SLURM_TMPDIR}
fi
