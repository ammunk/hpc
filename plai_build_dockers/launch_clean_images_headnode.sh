towers="chicago ithaca lowpoint sanjose berkeley ballston alexandria"
for t in "$towers"
do
    qsub -q desktop -l nodes="$t" -e "./hpc_output/${PBS_JOBID}.err" -o "./hpc_output/${PBS_JOBID}.out" clean_image.sh
done
