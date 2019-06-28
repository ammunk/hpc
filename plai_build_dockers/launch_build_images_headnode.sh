# takes exp_dir as argument

towers="chicago ithaca lowpoint sanjose berkeley ballston alexandria"
for t in $towers
do
    qsub -N "docker_builder" \
         -q desktop \
         -l "nodes=$t" \
         -e "./hpc_output/${PBS_JOBID}.err" \
         -o "./hpc_output/${PBS_JOBID}.out" \
         -v "EXP_DIR=$1"
         build_image_job.sh
done
