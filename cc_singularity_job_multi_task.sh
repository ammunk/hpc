#!/bin/bash

#SBATCH --account=rrg-kevinlb

# THIS SCRIPT IS CALLED OUTSIDE USING "sbatch"
# FOLLOWING ENV VARIABLES HAS TO BE PROVIDED:
#   - ntasks - number of tasks to run using srun
#   - GPUS_PER_TASK - number of each GPUS per task
#   - CMD - CMD should be a list of commands (one command for each task); len(CMD) = ntasks
#   - CONTAINER
#   - BASERESULTSDIR
#   - OVERLAYDIR_CONTAINER
#   - STUFF_TO_TAR - e.g. move the training data to the SLURM_TMPDIR for traning a network
#   - RESULTS_TO_TAR - the results we seek to move back from the temporary file; e.g. if we train an inference network we don't need to also move the training data back again

# see - https://docs.computecanada.ca/wiki/Using_GPUs_with_Slurm for why we add this
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK


#################################################

# Divide the "flattened string of commands into ntasks number of commands"
IFS=' ' read -a CMD <<< $CMD #

offset=$((${#CMD[@]} / $ntasks))
length=${#CMD[@]}
CMDs=()
for ((i = 0 ; i < $length ; i+=$offset)); do
    tmp=${CMD[@]:$i:$offset}
    CMDs+=("$tmp")
done

n_commands=${#CMDs[@]}
#################################################

module load singularity/3.2

# see eg. https://docs.computecanada.ca/wiki/A_tutorial_on_%27tar%27

# move data to temporary SLURM DIR which is much faster for I/O
echo "Copying singularity to ${SLURM_TMPDIR}"
time rsync -av "$CONTAINER" "$SLURM_TMPDIR"

# replace any "/"-character or spaces with "_" to use as a name
stuff_to_tar_suffix=$(tr ' |/' '_' <<< ${STUFF_TO_TAR})

if [ ! -z ${STUFF_TO_TAR} ]; then
    if [ ! -f "tar_ball_${stuff_to_tar_suffix}.tar" ]; then
        # make tarball in $BASERESULTSDIR
        echo "Creating tarball"
        time tar -cf "tar_ball_${stuff_to_tar_suffix}.tar" $STUFF_TO_TAR
    fi
fi

# go to temporary directory
cd "$SLURM_TMPDIR"

if [ ! -z ${STUFF_TO_TAR} ]; then
    echo "Moving tarball to slurm tmpdir"
    time tar -xf "${BASERESULTSDIR}/tar_ball_${stuff_to_tar_suffix}.tar"
fi

DB="db_${SLURM_JOB_ID}"
OVERLAY="overlay_${SLURM_JOB_ID}"
TMP="tmp_${SLURM_JOB_ID}"

# ensure resultsdir exists
if [ ! -d results ]; then
    mkdir results
fi

# make directory that singularity can mount to and use to setup a database
# such as postgresql or a monogdb etc. make a different DB for each task
for i in $(seq $n_commands); do
    mkdir "${DB}_${i}"
done

# make overlay directory, which may or may not be used
for i in $(seq $n_commands); do
    mkdir "${OVERLAY}_${i}"
done

# make tmp overlay directory otherwise /tmp in container will have very limited disk space
for i in $(seq $n_commands); do
    mkdir "${TMP}_${i}"
done

mem_per_task=$((${SLURM_MEM_PER_NODE} / ${SLURM_NTASKS}))

if [[ $GPUS_PER_TASK -ge 1 ]]; then
    srun_options="-n1 -N1 --gres=gpu:${GPUS_PER_TASK} --exclusive --mem=${mem_per_task} --cpu-bind=cores"
else
    srun_options="-n1 -N1 --exclusive --mem=${mem_per_task} --cpu-bind=cores"
fi

IFS=' ' read -a srun_options <<< "$srun_options"

counter=1
for cmd in "${CMDs[@]}"; do
    # --nv option: bind to system libraries (access to GPUS etc.)
    # --no-home and --containall mimics the docker container behavior
    # without those /home and more will be mounted be default
    # using "run" executed the "runscript" specified by the "%runscript"
    # any argument give "cmd" is passed to the runscript

    # for more info on srun see - https://docs.computecanada.ca/wiki/Advanced_MPI_scheduling
    # and https://slurm.schedmd.com/gres.html
    # and https://slurm.schedmd.com/srun.html
    srun ${srun_options[@]} bash -c \
        "module load singularity/3.2 && singularity run \
        --nv \
        -B results:/results \
        -B ${DB}_${counter}:/db \
        -B ${TMP}_{counter}:/tmp \
        -B ${OVERLAY}_${counter}:${OVERLAYDIR_CONTAINER} \
        --no-home \
        --contain \
        --writable-tmpfs \
        ${CONTAINER} \
       ${cmd}" &
    counter=$((counter + 1))
    sleep 1
done
# wait for each srun to finish
wait

######################################################################

# MAKE SURE THE RESULTS SAVED HAVE UNIQUE NAMES EITHER USING JOB ID AND
# OR SOME OTHER WAY - !!!! OTHERWISE STUFF WILL BE OVERWRITEN !!!!

######################################################################

if [ -z ${RESULTS_TO_TAR} ]; then
    # IF NO RESULTS TO TAR IS SPECIFIED - MAKE A TARBALL OF THE ENTIRE RESULTS DIRECTORY
    RESULTS_TO_TAR=("results")
else
    # if variable is provided make into an array
    IFS=' ' read -a RESULTS_TO_TAR <<< $RESULTS_TO_TAR
fi

# replace any "/"-character or spaces with "_" to use as a name
results_to_tar_suffix=$(tr ' |/' '_' <<< ${RESULTS_TO_TAR[@]})

# make a tarball of the results
time tar -cf "tar_ball_${results_to_tar_suffix}_${SLURM_JOB_ID}.tar" ${RESULTS_TO_TAR[@]}

# move unpack the tarball to the BASERESULTSDIR
cd $BASERESULTSDIR
tar --keep-newer-files -xf "${SLURM_TMPDIR}/tar_ball_${results_to_tar_suffix}_${SLURM_JOB_ID}.tar"
