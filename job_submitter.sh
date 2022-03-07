#!/bin/bas/bash

# get parent of parent directory from where this script is called
# (assumes submitted from source_dir/hpc_scripts)
source_dir="$(dirname "$(pwd)")"
project_name="$(echo ${source_dir} | awk -F/ '{print $NF}')"
gpu_type=""
time="00-01:00:00"
cpus=2
gpus=0
job_type="standard"
num_nodes=1
mem="10G"
account='rrg-kevinlb'
re='^[0-9]+$'
singularity_job=false
exp_configs_path="${source_dir}/hpc_files/experiment_configurations.txt"
hpc_files_dir="$(pwd)"
while [[ $# -gt 0 ]]; do
  arg="$1"
  case "$arg" in
    -a|--account)
      account="$2"
      allowed=("def-fwood" "rrg-kevinlb")
      if [[ ! " ${allowed[@]} " =~ " ${account} " ]]; then
        echo "Supported account options: def-fwood or rrg-kevinlb " >&2; exit 1
      fi
      shift 2
      ;;
    -h|--help)
      cat .help_message.txt
      exit
      ;;
    -g|--gpus)
      gpus="$2"
      if  [[ ! $gpus =~ $re ]] || [[ $gpus -le 0 ]]; then
        echo "error: gpus must be integer and bigger than 0" >&2; exit 1
      fi
      shift 2
      ;;
    -c|--cpus)
      cpus="$2"
      if  [[ ! $cpus =~ $re ]] || [[ $cpus -le 0 ]]; then
        echo "error: cpus must be integer and bigger than 0" >&2; exit 1
      fi
      shift 2
      ;;
    -W|--which-distributed)
      which_distributed="$2"
      allowed=("torchrun" "lightning")
      if [[ ! " ${allowed[@]} " =~ " ${which_distributed} " ]]; then
        echo "Supported distributed options: torchrun or lightning " >&2; exit 1
      fi
      shift 2
      ;;
    -t|--time)
      time="$2"
      shift 2
      ;;
    -m|--mem)
      mem="$2"
      mem_type="${mem##*[0-9]}"
      allowed=("G" "M")
      if [[ ! " ${allowed[@]} " =~ " ${mem_type} " ]]; then
        echo "Supported mnemory options: G or M " >&2; exit 1
      fi
      mem_amount="${mem%%[a-zA-Z]*}"
      if  [[ ! $mem_amount =~ $re ]] || [[ $mem_amount < 0 ]]; then
        echo "Amount of memory must be integer and non-negative" >&2; exit 1
      fi
      shift 2
      ;;
    -G|--gpu-type)
      gpu_type="$2"
      shift 2
      allowed=("p100" "p100l" "v100l")
      if [[ ! " ${allowed[@]} " =~ " ${gpu_type} " ]]; then
        echo "Supported gpu type options: p100 p100l v100l " >&2; exit 1
      fi
      ;;
    -e|--exp-name)
      exp_name="$2"
      shift 2
      ;;
    -j|--job-type)
      job_type="$2"
      shift 2
      allowed=("standard" "distributed" "sweep")
      if [[ ! " ${allowed[@]} " =~ " ${job_type} " ]]; then
        echo "Error: supported job types: standard distributed sweep " >&2; exit 1
      fi
      ;;
    -n|--num-nodes)
      num_nodes="$2"
      if  [[ ! $num_nodes =~ $re ]] || [[ $num_nodes -le 0 ]]; then
        echo "num_nodes must be integer and bigger than 0" >&2; exit 1
      fi
      shift 2
      ;;
    -d|--data)
      # https://tldp.org/LDP/abs/html/string-manipulation.html
      stuff_to_tmp="$(echo " $@" | awk -F' --| -' '{print $2}')" # includes the argument flag itself
      shift "$(echo "$stuff_to_tmp" | awk '{print NF}')"
      # remove argument flag
      stuff_to_tmp="$(cut -d ' ' -f2- <<< ${stuff_to_tmp} | sed 's/ *$//')"
      ;;
    -s|--singularity-container)
      singularity_container="$2"
      if [[ ! "$singularity_container" == *".sif" ]]; then
        echo "Invalid Singularity container path. File extension must be .sif " >&2; exit 1
      fi
      if [ -z ${work_dir} ]; then
        work_dir="workdir"
      fi
      shift 2
      ;;
    -w|--workdir)
      work_dir=$2
      shift 2
      ;;
    -C|--configs)
      exp_configs_path="$2"
      shift 2
      ;;
    *)
      unknown="$(echo " $@" | awk -F' --| -' '{print $2}')"
      echo "Unknown argument provided: ${unknown}"
      shift "$(echo "$unknown" | awk '{print NF}')"
      ;;
  esac
done

if [ ! -z "${SCRATCH}" ]; then
  scratch_dir="${SCRATCH}/${project_name}"
  if [ ! -z ${singularity_container} ]; then
    singularity_job=true
  fi

  if [ "${job_type}" == "distributed" ] && [ -z ${which_distributed} ]; then
    echo "Must specify the type of distributed job using [-W, --which_distributed]" >&2; exit 1
  fi

  # set the path to a file which contains the wandb api key
  WANDB_CREDENTIALS_PATH=~/wandb_credentials.txt
  WANDB_API_KEY=$(cat $WANDB_CREDENTIALS_PATH)

  if [ ! -d "${scratch_dir}/${exp_name}/checkpoints" ]; then
      mkdir -p "${scratch_dir}/${exp_name}/checkpoints"
  fi

  if [ ! -d "${scratch_dir}/hpc_outputs}" ]; then
    mkdir -p "${scratch_dir}/hpc_outputs"
  fi

  # create tarball
  if [ ! -z "${stuff_to_tmp}" ] && [ ! -f "${stuff_to_tmp}" ]; then
      stuff_to_tar_suffix="$(tr ' |/' '_' <<< ${stuff_to_tmp})"
      tarball="${scratch_dir}/tar_ball_${stuff_to_tar_suffix}.tar"

      if [ ! -f "${tarball}" ]; then
        echo "Creating tarball"
        time tar -cf "${tarball}" "${scratch_dir}/${stuff_to_tmp}"
      fi
  fi

  if [[ ! "${singularity_container}" == "true" ]]; then
    cd ${source_dir}

    # load the necessary modules, depend on your hpc env
    if [[ "$(hostname)" == *"cedar"* ]]; then
      module load python/3.9 cuda/11.4
    fi

    if [ ! -d virtual_env ]; then
      sbatch_virtualenv_cmd=(-W \
        -o "${SCRATCH}/python_virtualenv_installer_output.out" \
        --job-name="virtualenv-creator" --mem="10G")

      if [[ "$(hostname)" == *"borg"* ]]; then
          sbatch_virtualenv_cmd+=(--partition="plai")
      elif [[ "$(hostname)" == *"cedar"* ]]; then
          sbatch_virtualenv_cmd+=(--account="${account}")
      fi

      # install python packages as a submitted job
      # use -W to wait for the job to finish
      echo "Submitting virtualenv installer job"
      sbatch "${sbatch_virtualenv_cmd[@]}"  hpc_files/install_python_packages.sh &
      virtualenv_process_id=$!
      pending=0
      runnning=0
      submitted=0
      while ps | grep "${virtualenv_process_id}" 1> /dev/null; do
        job_query="$(squeue -u amunk | grep "virtualenv" | tr -s " " | sed 's/^ //')"
        job_id="$(echo "$job_query" | cut -d ' ' -f 1)"
        job_status="$(echo "$job_query" | cut -d ' ' -f 5)"

        if [ ! -z "${job_id}" ]; then
          case "$job_status" in
            PD)
              if (( pending == 0 )) ; then
                echo "Job ${job_id} is pending"
                pending=1
              fi
              ;;
            R)
              if (( running == 0 )) ; then
                echo "Job ${job_id} is running and installing virtual environment"
                running=1
              fi
              ;;
            *)
              echo "Status is neither R nor PD"
          esac
        else
          if (( submitted == 0 )) ; then
            echo "Job still being submitted"
            submitted=1
          fi
        fi
        sleep 2
      done
      # The variable $? always holds the exit code of the last command to finish.
      # Here it holds the exit code of $my_pid, since wait exits with that code.
      wait $virtualenv_process_id
      virtualenv_job_status=$?
      if (( virtualenv_job_status == 0 )); then
        echo "Finished installing virtualenv"
      else
        echo "Failed to install virtualenv" >&2; exit 1
      fi

    else
      echo "Virtual environment already exists"
    fi
    hpc_file_location="${source_dir}/hpc_files/virtual_env_hpc_files"
    args=("${tarball}")
  else
    hpc_file_location="${source_dir}/hpc_files/singularity_hpc_files"
    args=("${tarball}" "${workdir}")
  fi
  cd ${hpc_files_dir}

  if [[ ${job_type} == "sweep" ]]; then
    echo "About to submit a wandb sweep. Setting gpus=1 and num_nodes=1"
    gpus=1
    num_nodes=1
    which_distributed="" # ensure no distributed training
    read -p 'Specify sweeper id: '
    sweepid="${REPLY}"
    read -p 'Specify number of sweeps: '
    if  [[ ! ${REPLY} =~ $re ]]; then
      echo "number of sweeps must be integer" >&2; exit 1
    fi
    n_sweeps=${REPLY}
    hpc_file_location="${hpc_file_location}/standard_job.sh"
    if [[ "$(hostname)" == *"borg"* ]]; then
      sbatch_cmd=(--array 1-${n_sweeps}%10)
    elif [[ "$(hostname)" == *"cedar"* ]]; then
      sbatch_cmd=(--array 1-${n_sweeps})
    fi
    sbatch_cmd+=(--tasks-per-node=1 \
      --job-name="sweep-${project_name}-${exp_name}" \
      -o "${SCRATCH}/${project_name}/hpc_outputs/sweep_${exp_name}_%A_%a.out")
  elif [[ ${job_type} == "standard" ]]; then
    echo "About to submit a standard job. Setting num_nodes=1"
    num_nodes=1
    hpc_file_location="${hpc_file_location}/standard_job.sh"
    sbatch_cmd=(--tasks-per-node=1 \
      --job-name="standard-${project_name}-${exp_name}" \
      -o "${SCRATCH}/${project_name}/hpc_outputs/standard_${exp_name}_%j.out")
  elif [[ ${job_type} == "distributed" ]]; then
    echo "About to submit a ditributed job of type \"${which_distributed}\""
    sbatch_cmd=(-o "${SCRATCH}/${project_name}/hpc_outputs/${which_distributed}_${exp_name}_%N_%j.out" \
      --job-name="${which_distributed}_dist-${project_name}-${exp_name}")
    hpc_file_location="${hpc_file_location}/distributed_dispatcher.sh"
    if [[ ${which_distributed} == "lightning" ]]; then
      sbatch_cmd+=(--tasks-per-node=${gpus})
    elif [[ ${which_distributed} == "torchrun" ]]; then
      cpus=$((${cpus}*${gpus}))
      sbatch_cmd+=(--tasks-per-node=1)
    fi
  fi

  sbatch_cmd+=(--nodes="${num_nodes}" \
    --time="${time}" \
    --mem="${mem}"\
    --cpus-per-task="${cpus}")

  cmd=$(tr -d '\n\r\\' < "${exp_configs_path}")
  if [ ! -z "${sweepid}" ]; then
    cmd="$(sed -r 's/\/[0-9a-zA-Z]+$/\/'${sweepid}'/' <<< ${cmd})"
    echo "About to submit a sweep with the following command: ${cmd}"
  fi
  variables="scratch_dir=${scratch_dir},source_dir=${source_dir},\
exp_name=${exp_name},WANDB_API_KEY=${WANDB_API_KEY},cmd=${cmd},\
which_distributed=${which_distributed},\
singularity_container=${singularity_container}"

  if [[ $gpus > 0 ]]; then
      if [[ -z ${gpu_type} ]] || [[ "$(hostname)" == *"borg" ]]; then
        gres="--gres=gpu:${gpus}"
      else
        gres="--gres=gpu:${gpu_type}:${gpus}"
      fi
  else
    gres=""
  fi


  if [[ "$(hostname)" == *"borg"* ]]; then
      export SCORE_SDE_PATH='/ubc/cs/research/fwood/amunk/useful-python-repos/score_sde_pytorch'
      sbatch_cmd+=(--partition="plai")
      slurm_tmpdir="/scratch-ssd/${USER}"
      variables="${variables},SLURM_TMPDIR=${slurm_tmpdir}"
  elif [[ "$(hostname)" == *"cedar"* ]]; then
      export SCORE_SDE_PATH='/project/def-fwood/amunk/useful-python-repos/score_sde_pytorch'
      sbatch_cmd+=(--account="${account}")
  fi
  sbatch_cmd+=("${gres}" --export=ALL,"${variables}")

  function do_continue {
    echo "The following sbatch options will be set:"
    vars=("$@")
    echo "${vars[@]}"
    echo "Do you want to continue?"
    select yn in "Yes" "No"; do
      case $yn in
        Yes) break;;
        No) exit;;
      esac
    done
  }

  do_continue "${sbatch_cmd[@]}"
  sbatch "${sbatch_cmd[@]}" "${hpc_file_location}" "${args[@]}"
else
    echo "SCRATCH variable not assigned" >&2; exit 1
fi
