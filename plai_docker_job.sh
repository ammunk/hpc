# THIS SCRIPT IS CALLED OUTSIDE USING "qsub"
# FOLLOWING ENV VARIABLES HAS TO BE PROVIDED:
#   - CMD
#   - CONTAINER
#   - BASERESULTSDIR
#   - RESULTSDIR_CONTAINER

LOCAL="${BASERESULTSDIR}/${EXP_NAME}"
MOUNT="${RESULTSDIR_CONTAINER}"

if [ ! -d "$LOCAL" ]; then
    mkdir "$LOCAL"
fi

docker run --runtime=nvidia --rm \
       -v "${LOCAL}:${MOUNT}" \
       --name "${EXP_NAME}_${PBS_JOBID}" \
       "$CONTAINER" \
       "$CMD" > /dev/null
