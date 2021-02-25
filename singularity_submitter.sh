#!/bin/bash


# get parent of parent directory from where this script is called
# (assumes submitted from source_dir/hpc_scripts)
source_dir="$(dirname "$(pwd)")"
project_name="$(echo ${source_dir} | awk -F/ '{print $NF}')"
exp_name=""
data=""
seed=""
gpu_type="v100l"
time="00-01:00:00"
cpus=2
gpus=1
num_nodes=1
which_distributed="lightning"
mem_per_gpu="10G"
account='rrg-kevinlb'
re='^[0-9]+$'
while [[ $# -gt 0 ]]; do
  arg="$1"
  case "$arg" in
    -a|--account)
      account="$2"
      allowed=("def-fwood" "rrg-kevinlb")
      if [[ ! " ${allowed[@]} " =~ " ${which_distributed} " ]]; then
        echo "Supported account options: def-fwood or rrg-kevinlb " >&2; exit 1
      fi
      shift 2
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
    -wd|--which_distributed)
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
    -gs|--gpu_type)
      gpu_type="$2"
      shift 2
      allowed=("p100" "p100l" "v100l")
      if [[ ! " ${allowed[@]} " =~ " ${gpu_type} " ]]; then
        echo "Supported gpu type options: p100 p100l v100l " >&2; exit 1
      fi
      ;;
    -e|--exp_name)
      exp_name="$2"
      shift 2
      ;;
    -w|--wandb_sweepid)
      wandb_id="$2"
      shift 2
      ;;
    -n|--num_nodes)
      num_nodes="$2"
      if  [[ ! $num_nodes =~ $re ]] || [[ $num_nodes -le 0 ]]; then
        echo "num_nodes must be integer and bigger than 0" >&2; exit 1
      fi
      shift 2
      ;;
    -s|--seed)
      # manually set the seed. If left empty we create a random seed
      seed="$2"
      if  [[ ! $seed =~ $re ]]; then
        echo "num_nodes must be integer" >&2; exit 1
      fi
      shift 2
      ;;
    -d|--data)
      # https://tldp.org/LDP/abs/html/string-manipulation.html
      stuff_to_tmp="$(echo "$@" | awk -F'--' '{print $2}')"
      shift $(( "$(echo "$stuff_to_tmp" | awk '{print NF}')" ))
      ;;
    *)
      unknown="$(echo "$@" | awk -F'--' '{print $2}')"
      shift "$(( "$(echo "$unknown" | awk '{print NF}')" ))"
      ;;
  esac
done

if [ ! -z ${SCRATCH} ]; then
  scratch_dir="${SCRATCH}/${project_name}"

  cd ${source_dir}

  # set the path to a file which contains the wandb api key
  WANDB_CREDENTIALS_PATH=~/wandb_credentials.txt
  WANDB_API_KEY=$(cat $WANDB_CREDENTIALS_PATH)

  if [ ! -d "${scratch_dir}/${exp_name}/checkpoints" ]; then
      mkdir -p "${scratch_dir}/${exp_name}/checkpoints"
  fi

  if [ ! -d "${scratch_dir}/hpc_outputs}" ]; then
    mkdir -p "${scratch_dir}/hpc_outputs"
  fi


  if [ ! -z ${stuff_to_tmp}  ]; then
      stuff_to_tar_suffix=$(tr ' |/' '_' <<< ${stuff_to_tmp})
      tarball="${scratch_dir}/tar_ball_${stuff_to_tar_suffix}.tar"

      echo "Creating tarball"
      time tar -cf "${tarball}" \
          "${scratch_dir}/${stuff_to_tmp}"
  fi

  # # load the necessary modules, depend on your hpc env
  if [[ "$(hostname)" == *"cedar"* ]]; then
    module load python/3.8.2
  fi

  if [ ! -d virtual_env ]; then
    # setup virtual environment
    mkdir virtual_env
    python3 -m venv virtual_env
    source virtual_env/bin/activate

    pip install --upgrade pip
    pip install pipenv
    # we skip locking as it takes quite some time and is redundant
    # note that we use the Pipfile and not the Pipfile.lock here -
    # this is because compute canada's wheels may not include the specific
    # versions specified in the Pipfile.lock file. The Pipfile is a bit less
    # picky and so allows the packages to be installed. Although this could mean
    # slightly inconsistencies in the various versions of the packages.
    time pipenv install --skip-lock

    pip install torch==1.7.1+cu110 torchvision==0.8.2+cu110 \
        torchaudio===0.7.2 -f https://download.pytorch.org/whl/torch_stable.html
  else
    echo "Virtual environment already exists"
  fi

  if [ ! -z ${wandb_id} ]; then
    echo "About to submit a wandb sweep. Setting gpus=1 and num_nodes=1"
    gpus=1
    num_nodes=1
    which_distributed="" # ensure no distributed training
    read -p 'Specify number of sweeps: '
    if  [[ ! ${REPLY} =~ $re ]]; then
      echo "number of sweeps must be integer" >&2; exit 1
    fi
    n_sweeps=${REPLY}
  fi

  sbatch_cmd=(--nodes="${num_nodes}" \
    --time="${time}" \
    --mem-per-gpu="${mem_per_gpu}" \
    --account="${account}")

  if [ ! -z ${which_distributed} ]; then
    sbatch_cmd+=(-o "${SCRATCH}/${project_name}/hpc_outputs/${which_distributed}_${exp_name}_%j.out")
  else
    sbatch_cmd+=(-o "${SCRATCH}/${project_name}/hpc_outputs/sweep_${exp_name}_%A_%a.out")
  fi

  variables="scratch_dir=${scratch_dir},source_dir=${source_dir},exp_name=${exp_name},WANDB_API_KEY=${WANDB_API_KEY}"
  if [[ "$(hostname)" == *"borg"* ]]; then
      sbatch_cmd+=(--partition="plai" --gpus-per-node="${gpus}")
      slurm_tmpdir="/scratch-ssd/${USER}"
      variables="${variables},SLURM_TMPDIR=${slurm_tmpdir}"
  elif [[ "$(hostname)" == *"cedar"* ]]; then
      sbatch_cmd+=(--gpus-per-node="${gpu_type}:${gpus}")
  fi
  sbatch_cmd+=(--export=ALL,${variables})

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

  if [[ ${which_distributed} == "script" ]]; then
    echo "Submitting distributed job with SCRIPT backend"
    cpus=$((${cpus}*${gpus}))
    sbatch_cmd+=(--cpus-per-task="${cpus-per-node}" --tasks-per-node=${gpus} \
       --job-name="script_dist-${project_name}-${exp_name}")
    do_continue "${sbatch_cmd[@]}"
    sbatch "${sbatch_cmd[@]}" \
      ${source_dir}/hpc_files/distributed_scripts/distributed_dispatcher.sh \
      "${which_distributed}" "${seed}" "${tarball}"
  elif [[ ${which_distributed} == "lightning" ]]; then
    echo "Submitting distributed job with LIGHTING backend"
    sbatch_cmd+=(--cpus-per-task="${cpus}" --tasks-per-node=1 \
       --job-name="lightning_dist-${project_name}-${exp_name}")
    do_continue "${sbatch_cmd[@]}"
    sbatch "${sbatch_cmd[@]}" \
      ${source_dir}/hpc_files/distributed_scripts/distributed_dispatcher.sh \
      "${which_distributed}" "${seed}" "${tarball}"
  elif [ ! -z ${wandb_id} ]; then
    echo "Submitting sweeping job with sweep id: ${wandb_id}"
    if [[ "$(hostname)" == *"borg"* ]]; then
      sbatch_cmd+=(--array 1-${n_sweeps}%10)
    elif [[ "$(hostname)" == *"cedar"* ]]; then
      sbatch_cmd+=(--array 1-${n_sweeps})
    fi
    sbatch_cmd+=(--cpus-per-task="${cpus}" --tasks-per-node=1 \
       --job-name="sweep-${project_name}-${exp_name}")
    do_continue "${sbatch_cmd[@]}"
    cmd="wandb agent --count 1 muffiuz/tri-density-matching/${wandb_id}"
    sbatch "${sbatch_cmd[@]}" \
      ${source_dir}/hpc_files/cc_virtual_env_sweeper_job.sh "${tarball}" \
      "${cmd}"
  else
    echo "Distributed specification not supported" >&2; exit 1
  fi
else
    echo "SCRATCH variable not assigned" >&2; exit 1
fi
