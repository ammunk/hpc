# THIS SCRIPT IS CALLED OUTSIDE USING "qsub"
# FOLLOWING ENV VARIABLES HAS TO BE PROVIDED:
#   - CMD
#   - CONTAINER
#   - RESULTSDIR
#   - RESULTSDIR_CONTAINER

LOCAL="${RESULTSDIR}_${PBS_JOBID}"
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
