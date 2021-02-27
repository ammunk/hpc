#!/bin/bash

# get parent of parent directory from where this script is called
# (assumes submitted from source_dir/hpc_scripts)
source_dir="$(dirname "$(pwd)")"
project_name="$(echo ${source_dir} | awk -F/ '{print $NF}')"
gpu_type="v100l"
time="00-01:00:00"
cpus=2
gpus=1
job_type="standard"
num_nodes=1
mem_per_gpu="10G"
account='rrg-kevinlb'
re='^[0-9]+$'
singularity_job=false
exp_configs_path="${source_dir}/hpc_files/experiment_configurations.txt"
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
      echo .help_message.txt
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
      allowed=("script" "lightning")
      if [[ ! " ${allowed[@]} " =~ " ${which_distributed} " ]]; then
        echo "Supported distributed options: script or lightning " >&2; exit 1
      fi
      shift 2
      ;;
    -t|--time)
      time="$2"
      shift 2
      ;;
    -m|--mem-per-gpu)
      mem_per_gpu="$2"
      mem_type="${mem_per_gpu##*[0-9]}"
      allowed=("G" "M")
      if [[ ! " ${allowed[@]} " =~ " ${mem_type} " ]]; then
        echo "Supported mnemory options: G or M " >&2; exit 1
      fi
      mem_amount="${mem_per_gpu%%[a-zA-Z]*}"
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
      stuff_to_tmp="$(echo "$@" | awk -F'--' '{print $2}')"
      shift $(( "$(echo "$stuff_to_tmp" | awk '{print NF}')" ))
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
    -w|--work-dir)
      work_dir=$2
      shift 2
      ;;
    -C|--configs)
      exp_configs_path="$2"
      shift 2
      ;;
    *)
      unknown="$(echo "$@" | awk -F'--' '{print $2}')"
      shift "$(echo "$unknown" | awk '{print NF}')"
      ;;
  esac
done

if [ ! -z ${SCRATCH} ]; then
  scratch_dir="${SCRATCH}/${project_name}"
  if [ ! -z ${singularity_container} ]; then
    singularity_job=true
  fi

  if [ ${job_type} == "distributed" ] && [ -z ${which_distributed} ]; then
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
  if [ ! -z ${stuff_to_tmp}  ]; then
      stuff_to_tar_suffix=$(tr ' |/' '_' <<< ${stuff_to_tmp})
      tarball="${scratch_dir}/tar_ball_${stuff_to_tar_suffix}.tar"

      echo "Creating tarball"
      time tar -cf "${tarball}" \
          "${scratch_dir}/${stuff_to_tmp}"
  fi

  if [[ ! ${singularity_container} == true ]]; then
    cd ${source_dir}

    # load the necessary modules, depend on your hpc env
    if [[ "$(hostname)" == *"cedar"* ]]; then
      module load python/3.8.2
    fi

    if [ ! -d virtual_env ]; then
      # setup virtual environment
      mkdir virtual_env
      python3 -m venv virtual_env
      source virtual_env/bin/activate

      pip install --upgrade pip
      pip install torch==1.7.1+cu110 torchvision==0.8.2+cu110 \
          torchaudio===0.7.2 -f https://download.pytorch.org/whl/torch_stable.html
      if [ -f Pipfile ]; then
        pip install pipenv
        # we skip locking as it takes quite some time and is redundant
        # note that we use the Pipfile and not the Pipfile.lock here -
        # this is because compute canada's wheels may not include the specific
        # versions specified in the Pipfile.lock file. The Pipfile is a bit less
        # picky and so allows the packages to be installed. Although this could mean
        # slightly inconsistencies in the various versions of the packages.
        time pipenv install --skip-lock
      elif [ -f requirements.txt ]; then
        pip install -r requirements.txt
      else
        echo "No file specifying python packge dependencies."
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

  if [[ ${job_type} == "sweep" ]]; then
    echo "About to submit a wandb sweep. Setting gpus=1 and num_nodes=1"
    gpus=1
    num_nodes=1
    which_distributed="" # ensure no distributed training
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
    sbatch_cmd=(-o "${SCRATCH}/${project_name}/hpc_outputs/${which_distributed}_${exp_name}_%j.out" \
      --job-name="${which_distributed}_dist-${project_name}-${exp_name}")
    hpc_file_location="${hpc_file_location}/distributed_dispatcher.sh"
    if [[ ${which_distributed} == "lightning" ]]; then
      sbatch_cmd+=(--tasks-per-node=${gpus})
    elif [[ ${which_distributed} == "script" ]]; then
      cpu=$((${cpus}*${gpus}))
      sbatch_cmd+=(--tasks-per-node=1)
    fi
  fi

  sbatch_cmd+=(--nodes="${num_nodes}" \
    --time="${time}" \
    --mem-per-gpu="${mem_per_gpu}"\
    --cpus-per-task="${cpus}")

  cmd=$(tr -d '\n\r\\' < "${exp_configs_path}")
  variables="scratch_dir=${scratch_dir},source_dir=${source_dir},\
exp_name=${exp_name},WANDB_API_KEY=${WANDB_API_KEY},cmd=${cmd},\
which_distributed=${which_distributed},\
singularity_container=${singularity_container}"

  if [[ "$(hostname)" == *"borg"* ]]; then
      sbatch_cmd+=(--partition="plai" --gpus-per-node="${gpus}")
      slurm_tmpdir="/scratch-ssd/${USER}"
      variables="${variables},SLURM_TMPDIR=${slurm_tmpdir}"
  elif [[ "$(hostname)" == *"cedar"* ]]; then
      sbatch_cmd+=(--gpus-per-node="${gpu_type}:${gpus}" --account="${account}")
  fi
  sbatch_cmd+=(--export=ALL,"${variables}")

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
