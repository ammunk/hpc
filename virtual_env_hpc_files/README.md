# Virtual environment applications

## `requirements.txt` or `Pipfile`

The scripts will automatically create the virtual environment in `${source_dir}`
based on either a `${source_dir}/requirements.txt` or `${source_dir}/Pipfile`
file. If both are present the `Pipfile` will take precedence. The `Pipfile` is
the equivalent of a `requirements.txt` file but used by
[pipenv](https://pipenv.pypa.io/en/latest/) for creating and managing a
virtual environment.

## Providing experiment arguments

When doing a `wandb` sweep, the [sweeper.yml] file specifies the executed
commands. Otherwise you simply need to create a file (or just edit the
[experiment_configurations.txt] file) in which you put the command to be
executed within the virtual environment.

### Examples

#### `wandb` sweep

``` bash
# experiment_configurations.txt
wandb agent --count 1 WANDB_USERNAME/PROJECT_NAME/SWEEP_ID
```

#### Standard job

Change [experiment_configurations.txt] to read

``` text
# experiment_configurations.txt

python main.py --train --batch_size 6
```

or

``` text
# experiment_configurations.txt

python main.py \
--train \
--batch_size 6
```

### Adding your own configuration files

You can also create your own configuration files. Just provide the path to the
job submitter,

``` bash
bash job_submitter.sh --configs PATH_TO_YOU_CONFIG_FILE
```

#### Multi-node distributed gpu jobs

For multi-node gpu distributed training, these scripts assume you use PyTorch,
either manually using the `torch.distributed.launch` script or PyTorch
Lightning. However, since distributed applications need to know the number of
processes that communicate as well as where they are running etc. this
information must be provided somehow. The format for doing this depends on which
approach is taken, and these scripts force you to ensure that your application
can absorb additional arguments appropriate for each approach.

##### Distributed training managed by Lightning

A multi-node distributed gpu experiment managed by lightning **requires**
knowing the number of gpus per node, total number of nodes, master address, and
master port, world size, and node rank. However, when using `SLURM` the [master
address, port, world size, and node rank is [automatically
inferred](https://pytorch-lightning.readthedocs.io/en/stable/clouds/cluster.html#slurm-managed-cluster).

##### General purpose cluster

The only thing required is to make sure the following environement variables are
set:

- MASTER_PORT - required; has to be a free port on machine with NODE_RANK 0
- MASTER_ADDR - required (except for NODE_RANK 0); address of NODE_RANK 0 node
- WORLD_SIZE - required; how many nodes are in the cluster
- NODE_RANK - required; id of the node in the cluster

This can be accomplished manually, or by calling e.g. `torchrun` on each node
participating in the job.

##### SLURM scheduler

If using slurm PyTorch Lightning will infer the necessary job configurations
from the jobs environment variables assigned by SLURM. However, you **must**
call your program assigned

``` bash
srun python [your program].py
```

If you manually call srun multiple times and manually step through the tasks
this will interfere with Lightning's ability to infer the job configuration.

##### Argument to be consumed by your program

These scripts found in this repo will modify your provided command and add the
following `argparse`-formatted arguments **at the end**

- `--nnodes ${NNODES}`
- `--gpus ${NUM_TRAINERS}`

That is, if your command looks like this

```bash
python [your commands]
```
it will be changed to

```bash
python [your commands] --num_nodes number_of_nodes --gpus number_of_gpus_per_node 
```

You must there ensure that your experiment can absorb these additional arguments
and use them appropriately as shown in Lightning's
[documentation](https://pytorch-lightning.readthedocs.io/en/stable/clouds/cluster.html)

#### `torchrun` distributed job

Using `torchrun` you need to specify the master address, port, number of tasks
per node and number of nodes (if you use a single node, only the latter two are
required).

##### Single node example

``` bash
torchrun --nproc_per_node=${NUM_TRAINERS} --nnodes=1 \
    --standalone
    YOUR_TRAINING_SCRIPT.py (--arg1 --arg2 --arg3 and all other arguments of your training script)
```
##### Multinode example

``` bash
torchrun --nproc_per_node=${NUM_TRAINERS} --nnodes=${NNODES} \
    --rdzv_id=${JOBID} \
    --rdzv_backend=c10d \
    --rdzv_endpoint=${MASTER_ADDRESS}:${PORT} \
    YOUR_TRAINING_SCRIPT.py (--arg1 --arg2 --arg3 and all other arguments of your training script)
```

[experiment_configurations.txt]: ../experiment_configurations.txt
[sweeper.yml]: ../sweeper.yml
