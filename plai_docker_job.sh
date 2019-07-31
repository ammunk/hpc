# THIS SCRIPT IS CALLED OUTSIDE USING "qsub"
# FOLLOWING ENV VARIABLES HAS TO BE PROVIDED:
#   - CMD
#   - CONTAINER
#   - BASERESULTSDIR
#   - RESULTSDIR_CONTAINER

LOCAL="${BASERESULTSDIR}"

if [ ! -d "$LOCAL" ]; then
    mkdir "$LOCAL"
fi

docker run --runtime=nvidia --rm \
       -v "${LOCAL}:/results" \
       --name "${EXP_NAME}_${PBS_JOBID}" \
       "$CONTAINER" \
       "$CMD"
