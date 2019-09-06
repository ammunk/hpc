#PBS -o hpc_output/${PBS_JOBID}.out
#PBS -e hpc_output/${PBS_JOBID}.err

# THIS SCRIPT IS CALLED OUTSIDE USING "qsub"
# FOLLOWING ENV VARIABLES HAS TO BE PROVIDED:
#   - CMD
#   - CONTAINER
#   - BASERESULTSDIR
#   - OVERLAYDIR_CONTAINER
#   - RESULTSDIR_CONTAINER

DB="db_${PBS_JOBID}"
OVERLAY="overlay_${PBS_JOBID}"
TMP="tmp_${PBS_JOBID}"

cd "$BASERESULTSDIR"

# ensure resultsdir exists
if [ ! -d results ]; then
    mkdir results
fi

# make directory that singularity can mount to and use to setup a database
# such as postgresql or a monogdb etc.

if [ ! -d "$DB" ]; then
    mkdir "$DB"
fi

# make overlay directory, which may or may not be used
if [ ! -d "$OVERLAY" ]; then
    mkdir "$OVERLAY"
fi

# make tmp overlay directory otherwise /tmp in container will have very limited disk space
if [ ! -d "$TMP" ]; then
    mkdir "$TMP"
fi

echo "COMMANDS GIVEN: ${CMD}"
echo "STUFF TO TAR: ${STUFF_TO_TAR}"
echo "RESULTS TO TAR: ${RESULTS_TO_TAR}"

# --nv option: bind to system libraries (access to GPUS etc.)
# --no-home and --contain mimics the docker container behavior
# without those /home and more will be mounted be default
# using "run" executed the "runscript" specified by the "%runscript"
# any argument give "CMD" is passed to the runscript
/usr/local/bin/singularity run \
            --nv \
            -B "results:/results" \
            -B "${DB}":/db \
            -B "${TMP}":/tmp \
            -B "${OVERLAY}":"${OVERLAYDIR_CONTAINER}" \
            --cleanenv \
            --no-home \
            --contain \
            --writable-tmpfs \
            "$CONTAINER" \
            "$CMD" | tee -a ${EXP_DIR}/hpc_scripts/hpc_out/output_${PBS_JOBID}.txt

# remove temporary directories
rm -r "$OVERLAY" "$DB" "$TMP"
