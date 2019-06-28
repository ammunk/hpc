#PBS -N build-raven-docker
#PBS -M "amunk@cs.ubc.cs"
#PBS -V
#PBS -m abe
#PBS -q desktop

# Set output and error directories
#PBS -o "../hpc_outputs/build_images${PBS_JOBID}.out"
#PBS -e "../hpc_outputs/build_images${PBS_JOBID}.err"

WORKDIR="/ubc/cs/research/fwood/amunk/research/simulator_compilation/simulator-compilation/experiments"
cd ${WORKDIR}/RAVEN/simulator
bash build_docker
