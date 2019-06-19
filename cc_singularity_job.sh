#SBATCH --account=rrg-kevinlb

# THIS SCRIPT IS CALLED OUTSIDE USING "sbatch"
# FOLLOWING ENV VARIABLES HAS TO BE PROVIDED:
#   - CMD
#   - CONTAINER
#   - BASERESULTSDIR
#   - RESULTSDIR_CONTAINER

module load singularity/3.1
module load CUDA

LOCAL="${BASERESULTSDIR}_${SLURM_JOB_ID}"
MOUNT="${RESULTSDIR_CONTAINER}"

if [ ! -d "$LOCAL" ]; then
    mkdir "$LOCAL"
fi

# --nv option: bind to system libraries (access to GPUS etc.)
singularity exec \
            --nv \
            -B "${LOCAL}:${MOUNT}" \
            --no-home \
            --contain \
            "$CONTAINER" \
            "$CMD"
