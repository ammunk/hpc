# HPC scripts for PLAI and Cedar (Compute Canada)

The approach taken here rely on **bash** as opposed to **python**, and the hpc
scripts serve one of three (overlapping) purposes:

- [Multi-node distributed GPU training](#multi-node-distributed-training) of
  [PyTorch](https://pytorch.org/) models
- [Singuarity](https://sylabs.io/guides/3.7/user-guide.pdf) or virtual
  environment based projects
- [Weights and Biases sweeper](https://docs.wandb.ai/sweeps) jobs (great for
  hyperparameter searches)
  
The scripts are designed in order to make the transfer of a locally working
application to the hpc clusters as easy and painless as possible.
  
There are two types of scripts, which differ by how dependencies are managed for
your application: a **Singularity containers** or a **python virtual
environments**. The Singularity approach offers full flexibility where all
dependencies are specified in a "Singularity file", whereas the python virtual
environment approach (obviously) must be a python application.
  
To use these scripts, simply copy them into your **[appropriately
structured](#project-structure)** project. The scripts are written to be
(almost) project agnostic, which effectively means that the scripts will:

- Automatically set up the experiments which prevents mixing different projects
and their experiments.

- Ensure the correct relationship between requested number of *gpus*, *nodes*,
and *cpus per gpu* depending on the type of distributed job. 

- [Manage the transfer](#copying-datasets-and-other-files-to-slurm_tmpdir) of
user specified files and directories to and from the local nodes for faster
read/write operations - i.e. `SLURM_TMPDIR`.

The created folders and their location are easily accessible as [environment
variables](#environment-variables). One thing to pay attention to is that
Singularity based jobs needs additional folders than the virtual environment
based ones. For details see the [created folders](#created-folders).

#### Important:

The scripts rely on the `SCRATCH` environment variable. This is **not** set by
default on the PLAI machines. To use these scripts on the PLAI cluster, add

``` bash
export SCRATCH=/ubc/cs/research/plai-scratch/amunk
```
to your `~/.bashrc`.

Additionally, you will notice references to the `SLURM_TMPDIR`

#### 

## Submitting jobs

To submit jobs call one of two submitter jobs. Which one depends on whether your
application uses Singularity or a virtual environment. 

These scripts distinguish between two types of jobs:

- Array jobs for hyperparameter searches using `wandb` sweeps
- Single jobs which supports multi-node distributed gpu applications

The options that control the job submissions are:

``` text
-a, --account               Account to use on cedar (def-fwood, rrg-kevinlb). 
                              Ignored on the PLAI cluster. Default: rrg-kevinlb
-g, --gpus                  Number of gpus per node. Default: 1
-c, --cpu                   Number of cpus per node: Default: 2
-wd, --which-distributed    Kind of distributed gpu application backend used
                              (lightning, script). Default: lightning
-t, --time                  Requested runtime. Format: dd-HH:MM:SS. 
                              Default: 00-01:00:00
-m, --mem-per-gpu           Amount of memory per requested gpu. E.g. 10G or 10M.
                              Default: 10G
-gt, --gpu-type             Type of gpu to use (p100, p100l, v100l). Ignored on
                              the PLAI cluster. Default: v100l
-e, --exp-name              Name of the experiment. Used to created convenient 
                              folders in ${SCRATCH}/${project_name} and to name 
                              the generated output files. Default: "" (empty)
-w, --wandb-sweepid         The wandb sweep id. When specified the scripts will
                              submit an array job. The script determine the 
                              number of array jobs by promting the user for the 
                              number of sweeps. Array jobs will only request a 
                              single (1) gpu on a single (1) node
-n, --num_nodes             Number of nodes. Default: 1
-d, --data                  Whitespace separated list of paths to directories or 
                              files to transfer to ${SLURM_TMPDIR}. These paths 
                              MUST be relative to ${SCRATCH}/${project_name}.
```

#### Examples

Assume we have a project with the [appropriate structure](#project-structure)

``` text
your_project_name
├── hpc_files
│   ├── singularity_submitter.sh
│   ├── virtual_env_submitter.sh
│   └── application_configuration.txt
├── Pipfile
├── requirements.txt
├── singularity_container.sif
│  
.
. project source files
.
```

To submit a job first `cd [path_to_project]/hpc_files`, and then

##### Singularity based

``` bash
bash singularity_submitter.sh \
  --gpus 2 \
  --cpus 2 \
  --exp_name testing \
  --num_nodes 2
```

##### Virtual environment based

``` bash
bash virtual_env_submitter.sh \
  --gpus 2 \
  --cpus 2 \
  --exp_name testing \
  --num_nodes 2
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

### How to specify experiment configurations:

The scripts will read the experiment configurations from
[application_configurations.txt](application_configurations.txt).



## Copying datasets and other files to `SLURM_TMPDIR`

## Multi-node distributed training

### Lightning (recommended)

### pytorch.distributed.launch

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
- `scratch_dir`: path to a folder created on `SCRATCH`. This folder is
  project specific and is created using `project_name`. No need to worry about
  having multiple different project overwrite one another.
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

The path to these folder are sensibly named within the scripts and can be
referenced as **environment variables**.

## Project structure

Regardless of whether your project uses Singularity or virtual environments the
scripts assumes a certain structure

``` text

```

## Weight and biasses

## TODO
- [ ] Support multi-node distributed GPU training for Singularity based jobs.
- [ ] Make script to transfers data from scratch to allocated nodes. This script
      should be executed before the computation script.
- [ ] Add a repeat option to do mulit-seeded experiments.
- [ ] A single file with application configuration.
- [ ] Check if a wandb sweeper id is in the application configurations. If it
      is, it should take precedence over a job submitter specified wandb sweep
      id. Print a warning statement if these two differ.
- [ ] Remove seed option. Make part of application configurations
