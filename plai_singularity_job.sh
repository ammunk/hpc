# THIS SCRIPT IS CALLED OUTSIDE USING "qsub"
# FOLLOWING ENV VARIABLES HAS TO BE PROVIDED:
#   - CMD
#   - CONTAINER
#   - RESULTSDIR
#   - RESULTSDIR_CONTAINER

cd $EXP_DIR

LOCAL="${RESULTSDIR}/${EXP_NAME}_${PBS_JOBID}"
MOUNT="${RESULTSDIR_CONTAINER}"

if [ ! -d "$LOCAL" ]; then
    mkdir "$LOCAL"
fi

# make directory that singularity can mount to and use to setup a database
# such as postgresql or a monogdb etc.
mkdir db

# --nv option: bind to system libraries (access to GPUS etc.)
# --no-home and --contain mimics the docker container behavior
# without those /home and more will be mounted be default
# using "run" executed the "runscript" specified by the "%runscript"
# any argument give "CMD" is passed to the runscript
singularity exec \
            --nv \
            -B "${LOCAL}:${MOUNT}" \
            -B db:/db \
            --no-home \
            --contain \
            "$CONTAINER" \
            "$CMD"
