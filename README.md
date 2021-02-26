# SLURM hpc scripts

The approach taken here rely on **bash** as opposed to **python**, and the hpc
scripts serve one of three (overlapping) purposes:

- [Multi-node distributed GPU training](#multi-node-distributed-gpu-training) of
  [PyTorch](https://pytorch.org/) models
- [Singuarity](https://sylabs.io/guides/3.7/user-guide.pdf) or virtual
  environment based projects
- [Weights and Biases sweeper](https://docs.wandb.ai/sweeps) jobs (great for
  hyperparameter searches)
  
The scripts are designed in order to make the transfer of a locally working
application to the hpc clusters as easy and painless as possible.
  
There are two types of scripts, which differ by how dependencies are managed for
your application: 

- **Singularity containers**
- **python virtual environments** 

The Singularity approach offers much greater flexibility where all dependencies
are specified in a "Singularity file", whereas the python virtual environment
approach (obviously) must be a python application.

Depending on whether you use Singularity or a python virtual environment they
each pose slightly different constraints on how experiments run once a job has
been submitted. These constraints are minimal so that you do not have to give up
e.g. Singularity's flexibility yet ensures the script can make some assumptions
about how to run your experiments. These details on this can be found in the
[Singularity readme] or the [virtual environment readme].
  
To use these scripts, simply copy them into your **[appropriately
structured](#project-structure)** project. The scripts are written to be
(almost) project agnostic, which effectively means that the scripts will:

- Automatically set up the experiments which prevents mixing different projects
and their experiments.

- Ensure the correct relationship between requested number of *gpus*, *nodes*,
and *cpus per gpu* depending on the type of distributed job. 

- [Manage the transfer](#copying-datasets-and-other-files-to-slurm_tmpdir) of
user specified files and directories to and from the local nodes for faster
read/write operations - i.e. using `SLURM_TMPDIR`.

The created folders and their location are easily accessible as [environment
variables](#environment-variables). One thing to pay attention to is that
Singularity based jobs needs additional folders than the virtual environment
based ones. For details see the [created folders](#created-folders).

#### Important:

The scripts rely on the `SCRATCH` environment variable. This is **not** set by
default on the PLAI machines. To use these scripts on the PLAI cluster, add

``` bash
export SCRATCH=/ubc/cs/research/plai-scratch/${USER}
```
to your `~/.bashrc`.

Additionally, you will notice references to the `SLURM_TMPDIR`. This variable
points to a temporary directory created for each job. If the job is allocated
multiple nodes the temporary directory is created on each node. These
directories are already automized by Compute Canada on Cedar. However, this is
not the case on the PLAI cluster, and so these scripts will instead mimic this
behavior and subsequently remove these temporary directories upon job
completion. Please refer to [PLAI `SLURM_TMPDIR`](#plai-slurm_tmpdir) for
further details.

## Submitting jobs

To submit jobs call one of two submitter jobs. Which one depends on whether your
application uses Singularity or a virtual environment. Note that the job
submitter file by default assumes you use a virtual environment. To specify a
Singularity based job, use the `-s, --singularity-container` option.

The scripts distinguish between two types of jobs, and how to specify the
experiment's configurations depend on which type:

- Array jobs for hyperparameter searches using `wandb` sweeps - see [integration
  with Weights and Biases](#integration-with-weight-and-biases) for more
  details.
- Single jobs which supports multi-node distributed gpu applications
  - The experiments configurations are specified using the
    [experiment_configuration.txt] file. It's
    format differs slightly depending on whether you use Singularity or a
    virtual environment. For details, see the [Singularity readme] or the
    [virtual environment readme].

The options that control the job submissions are:

``` text
-a, --account                 Account to use on cedar (def-fwood, rrg-kevinlb). 
                                Ignored on the PLAI cluster. Default: rrg-kevinlb
-g, --gpus                    Number of gpus per node. Default: 1
-c, --cpu                     Number of cpus per node: Default: 2
-W, --which-distributed      Kind of distributed gpu application backend used
                                (lightning, script). Default: lightning
-t, --time                    Requested runtime. Format: dd-HH:MM:SS. 
                                Default: 00-01:00:00
-m, --mem-per-gpu             Amount of memory per requested gpu. E.g. 10G or 10M.
                                Default: 10G
-G, --gpu-type               Type of gpu to use (p100, p100l, v100l). Ignored on
                                the PLAI cluster. Default: v100l
-e, --exp-name                Name of the experiment. Used to created convenient 
                                folders in ${SCRATCH}/${project_name} and to name 
                                the generated output files. Default: "" (empty)
-w, --wandb-sweepid           The wandb sweep id. When specified the scripts will
                                submit an array job. The script determine the 
                                number of array jobs by promting the user for the 
                                number of sweeps. Array jobs will only request a 
                                single (1) gpu on a single (1) node
-n, --num_nodes               Number of nodes. Default: 1
-d, --data                    Whitespace separated list of paths to directories or 
                                files to transfer to ${SLURM_TMPDIR}. These paths 
                                MUST be relative to ${SCRATCH}/${project_name}.
-s, --singularity-container   Path to singularity container. If specified the 
                                job is submitted as a Singularity based job
-C, --configs                 Path to file specifying the experiment 
                                configuration. Default: experiment_configurations.txt
```
#### Example

Assume we have a project with the [appropriate structure](#project-structure)


To submit a job first `cd [path_to_project]/hpc_files`, and then

``` bash
bash job_submitter.sh \
  --gpus 2 \
  --cpus 2 \
  --exp-name testing \
  --num-nodes 2
```

### Integration with Weights and Biases

To use the [Weight and Biases](https://wandb.ai/) sweeps, you need to first
install `wandb` into your Singularity container or virtual environment,

``` python
pip install wandb
```

To use `wandb` requires a user login. Either do `wandb login`, where `wandb`
will prompt for a username and password, or circumvent logging in by instead
setting the `WANDB_API_KEY` environment variable to the api key provided by
weight and biases after you sign up.

The scripts found here take the latter approach by searching for your api key in
`~/wandb_credentials.txt`. As long as you copy your api key into
`~/wandb_credentials.txt` on cedar and the PLAI cluster you can perform sweeps
and your application can log experiment progress using `wandb`.

#### Sweeper jobs

When you submit a `wandb` sweep array job, you only need to specify the sweep
id. That is, first initiate the sweep (either locally or one of the cluster),

``` bash
wandb sweep sweeper.yml
```

This will create a pending sweep on `wandb`'s servers. Then in
`project_root/hpc_files` do

``` bash
bash job_submitter.sh \ # or singularity_submitter.sh 
  --wandb-sweepid [some id]
```

The script will then prompt for the number of sweeps which will `wandb` will
track as part of the sweep.

The provided [sweeper.yml] file can serve as a template, but should be
modified to your specific sweep. Think of the [sweeper.yml] file as the
sweep's equivalent of the more general
[experiment_configuration.txt] file.

### How to specify experiment configurations:

- For sweep jobs edit `sweeper.yml`.
- Otherwise edit [experiment_configurations.txt]. See the [Singularity readme]
  or [virtual environment readme] for the format.

## Copying datasets and other files to `SLURM_TMPDIR`

To copy data to the local nodes when submitting a job, simply use the `-d,
--data` option. To transfer multiple files and directories specify these using a
whitespace separated list of **relative** paths.

The main purpose of this functionality is to copy large amounts of data, which
typically is stored on `${SCRTACH}`. This would for instance be large datasets,
etc. Therefore, the paths are going to be relative to
`${SCRATCH}/${project_name}`. The script will then create a tarball using `tar`
and transfer the files and directories to `${SLURM_TMPDIR}`. You can then access
the files and directories on `${SLURM_TMPDIR}` using the same paths used when
using the `-d, --data` option.

### Example

Assume you have work on a project named `project_root`, and on `${SCRATCH}` you
have,

``` text
${SCRATCH}
├── project_root
│   └── datasets
│       ├──dataset1
│       ├──dataset2
│       └──dataset3
.
. other files on scratch
.
```

If you want to move the entire directory `datasets` to `${SLURM_TMPDIR}`, you
would do

``` bash
bash job_submitter.sh \
  --data datasets
```

This would then lead to the following structure on `${SLURM_TMPDIR}`

``` text
${SLURM_TMPDIR}
├── datasets
│   ├── dataset1
│   ├── dataset2
│   └── dataset3
```

If instead you want to move only `dataset1` and `dataset2`, you would do

``` bash
bash job_submitter.sh \
  --data datasets/dataset1 datasets/dataset2
```
This would then lead to the following structure
``` text
${SLURM_TMPDIR}
├── datasets
│   ├── dataset1
│   └── dataset2
```

In your specific experiment, you could then have an option to specify the
location of a dataset (using e.g. python's `argparse`). You could then configure
to look for `dataset1` by doing

``` bash
python my_program.py --data_dir=${SLURM_TMPDIR}/datasets/dataset1 [other arguments]
```

## Multi-node distributed gpu training

The scripts have been tested with two different ways to do multi-node
distributed gpu training with [PyTorch]('https://pytorch.org/'),

- Using PyTorch's [launch
  script](https://github.com/pytorch/pytorch/blob/master/torch/distributed/launch.py)
- [PyTorch Lightning](https://www.pytorchlightning.ai/)


The practical difference in terms of submitting a job is what each approach
considers a task. The hpc scripts found in this repo will make sure to submit a
job with the appropriate relationship between gpus, nodes, and cpus.

In terms of writing the application code, Lightning removes a lot of the
distributed training setup and does this for you. It also offers multiple
optimization tricks that have been found to improve training of neural network
based models. The downside is that Lightning is (slightly) more rigid in terms
of managing the gpus across the distributed processes. Using PyTorch's launch
script offers full flexibility, but requires manually setting up the distributed
training.

To get comfortable with these different approaches and play around with them
check out my [distributed training
repository](https://github.com/ammunk/distributed-training-pytorch) which also
uses the hpc scripts found here.

### Lightning (recommended)

Lightning is built on pure PyTorch, and requires your code to be written using a
certain structure (which is rather intuitive and sensible). It has a lot of
functionality, but it attempts to streamline the training process to be agnostic
to any particular neural network training program. Lightning includes loads of
functionalities, but fundamentally you can think of Lightning as doing the
training loop for you. You only have to write the training step, which is then
called by Lightning.

The benefit of the design of Lightning is that Lightning manages distributing
your code across multiple gpus without you having to really change your code.

#### Activate virtual environment before calling `srun`
One caveat when using Lightning is that 

### torch.distributed.launch

If you use the `torch.distributed.launch` approach you achieve full flexibility
in how to manage the gpus for each process. Under the hood
`torch.distributed.launch` spawns subprocesses, and requires you to specify
which machine the "master" machine as well as which port these processes use to
communicate to each other.

If you use a virtual environment for you application, the hpc scripts provided
in this repo handles this for you. However, if you use Singularity you have to
manage this yourself: either as a command passed to the Singularity container or
build the Singularity container to take care of this.

The [launch
script](https://github.com/pytorch/pytorch/blob/master/torch/distributed/launch.py)
comes with the installation of PyTorch, and should be executed on **each node**
using the following pattern,

``` bash
python -m torch.distributed.launch --nproc_per_node=NUM_GPUS_YOU_HAVE
               --nnodes=2 --node_rank=0 --master_addr="192.168.1.1"
               --master_port=1234 YOUR_TRAINING_SCRIPT.py (--arg1 --arg2 --arg3
               and all other arguments of your training script)
```

See the
[virtual_env_hpc_files/distributed_scripts/lightning_launcher.sh](virtual_env_hpc_files/distributed_scripts/lightning_launcher.sh)
file for how this is handled if you use a virtual environment approach.

## Environment variables

The scripts assign following environment variables which. These are used
internally, and are also meant to be used downstream within a program.

Some are automatically inferred from the name of the project folder, while other
should be manually (optional) specified. The variables are then available
within your program using e.g. python's `os` package:

``` python
import os
source_dir = os.environ['source_dir']
```

### Automatically assigned

- `source_dir`: absolute path to the root of the project.
- `project_name`: set to be the name of the project folder.
- `scratch_dir=${SCRATCH}/${project_name}`: path to a folder created on
  `SCRATCH`. This folder is project specific and is created using
  `project_name`. No need to worry about having multiple different project
  overwrite one another.
  - This path should be considered the "root" location of the project to store
    large files - e.g. model checkpoints etc.
  - Since this is on `SCRATCH` read/write operation may be **slow**. Try
    using `path_to_local_node_storage=${SLURM_TMPDIR}` instead.
  - For project using **datasets**, place these somewhere here.

### Manually (optional) assigned
- `exp_name`: a name which describe the current experiment belonging to the
  overarching project (`project_name`)
  - For instance, the project could be "gan_training". An experiment could
    then be `exp_name=celebA` for training a GAN to generate images of faces.

## Created folders

The scripts will automatically create the following directories. Your experiment
can easily access these using the created [environment
variables](#environment-variables). They are only created if they do not already
exist.

- `${SCRATCH}/${project_name}`: if you have a dataset on scratch, you should
  create this directory yourself and put whatever data you need for your jobs
  here.
- `${scratch_dir}/hpc_outputs`: location of yours jobs' output files
- `${scratch_dir}/exp_name/checkpoints`: a directory meant to store checkpoints
  and other files created as your experiment runs.

## Project structure

Regardless of whether your project uses Singularity or virtual environments the
scripts assumes a certain structure

``` text
your_project_name
├── hpc_files
│   ├── job_submitter.sh
│   └── experiment_configuration.txt
├── Pipfile
├── requirements.txt
├── singularity_container.sif
│  
.
. project source files
.
```

## PLAI `SLURM_TMPDIR`

The `SLURM_TMPDIR` not provided on the PLAI cluster (but is on cedar). This is
why the scripts will check if you submit your job on the PLAI cluster and set
this for you - `SLURM_TMPDIR=/scratch-ssd/${USER}`.

The scripts will then create the temporary directory for each job on each node.
Upon completion of the job the directory will be deleted. Bear in mind, however,
that should the job end prematurely due to hitting the time limit or the job
simply crashed, the cleanup will not happen.

### Keeping PLAI local storage clean

To keep the local storages clean on the PLAI cluster, consider running the
[cleanup script](plai_cleanups/submit_plai_cleanup). This script submits a
job to each machine on the plai cluster and removes all directories and files
found in `/scratch-ssd` that matches the pattern `${USER}*`.

## TODO
- [ ] Support multi-node distributed GPU training for Singularity based jobs.
- [ ] Make script to transfers data from scratch to allocated nodes. This script
      should be executed before the computation script.
- [ ] Add a repeat option to do multi-seeded experiments.
- [ ] A single file with application configuration.
- [ ] Check if a wandb sweeper id is in the application configurations. If it
      is, it should take precedence over a job submitter specified wandb sweep
      id. Print a warning statement if these two differ.
- [ ] Remove seed option. Make part of application configurations

[sweeper.yml]: (sweeper.yml)
[Singularity readme]: (singularity_hpc_files/README.md)
[virtual_environment readme]: (/virtual_env_hpc_files/README.md)
[experiment_configurations.txt]: (experiment_configurations.txt)
