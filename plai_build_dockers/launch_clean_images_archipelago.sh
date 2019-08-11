# takes docker_image as argument

for n in "01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28"
do
    qsub -N "docker_cleaner" \
         -q batch \
         -l "nodes=archipelago$n" \
         -e "./hpc_output/${PBS_JOBID}.err" \
         -o "./hpc_output/${PBS_JOBID}.out" \
         -v "DOCKER_IMAGE=$1" \
         clean_image.sh
done