#!/bin/bash

tarball="$1"
gpus=$(echo ${SLURM_GPUS_PER_NODE} | cut -d ":" -f 2)

cd ${source_dir}
source virtual_env/bin/activate

# check if srun (and therefore scontrol etc) exists
if ! srun -v COMMAND &> /dev/null
then
   PATH=/opt/slurm/bin:${PATH}
fi

if [[ "${SLURM_TMPDIR}" == *"scratch-ssd"* ]]; then
  SLURM_TMPDIR="${SLURM_TMPDIR}_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
fi

var=(`scontrol show hostname $SLURM_NODELIST`)

num_nodes=${#var[@]}
scripts_dir="${source_dir}/hpc_files/distributed_scripts"
if [[ ${which_distributed} == "script" ]]; then
  for i in `seq 0 $(echo $num_nodes -1 | bc)`;
  do
      echo "launching ${i} job on ${var[i]} with master address ${var[0]}"
      srun -w ${var[$i]} -N 1 -n 1 \
        bash ${scripts_dir}/script_launcher.sh \
        ${num_nodes} ${i} ${gpus} ${var[0]} ${tarball} &
  done
  wait
elif [[ ${which_distributed} == "lightning" ]]; then
  srun bash ${scripts_dir}/lightning_launcher.sh ${num_nodes} ${gpus} ${tarball}
else
    echo "Distributed specification not supported" >&2; exit 1
fi

echo "FINISHED DISTRIBUTED JOB"
echo "========================"

if [[ "${SLURM_TMPDIR}" == *"scratch-ssd"* ]]; then
  srun rm -r ${SLURM_TMPDIR}
fi
