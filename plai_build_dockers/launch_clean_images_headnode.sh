# takes docker_image as argument

towers="chicago ithaca lowpoint sanjose berkeley ballston alexandria"
for t in "$towers"
do
    qsub -N "docker_cleaner" \
         -q desktop \
         -l nodes="$t" \
         -e "./hpc_output/${PBS_JOBID}.err" \
         -o "./hpc_output/${PBS_JOBID}.out" \
         -v "DOCKER_IMAGE=$1" \
         clean_image.sh
done
