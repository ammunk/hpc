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
knowing the number of gpus per node and total number of nodes. Therefore the
script here will modify your provided command and add the following
`argparse`-formatted arguments **at the end**

- `--num_nodes number_of_nodes`
- `--gpus number_of_gpus_per_node`

That is, if your command looks like this

```bash
python [your commands]
```
it will be changed to

```bash
python [your commands] --num_nodes number_of_nodes --gpus number_of_gpus_per_node 
```

You must there ensure that your experiment can absorb these additional arguments
and use them appropriately as described in Lightning's
[documentation](https://pytorch-lightning.readthedocs.io/en/stable/advanced/multi_gpu.html#distributed-data-parallel).

#### `torchrun` distributed job

Using `torchrun` set the `LOCAL_RANK` (process rank on the local node),
`LOCAL_WORLD_SIZE` (number of processes on each node), and `GLOBAL_WORLD_SIZE`
(total number of processes) environment variables. Use these for setting up your
distributed program.

### Adding your own configuration files

You can also create your own configuration files. Just provide the path to the
job submitter,

``` bash
bash job_submitter.sh --configs PATH_TO_YOU_CONFIG_FILE
```

[experiment_configurations.txt]: ../experiment_configurations.txt
[sweeper.yml]: ../sweeper.yml
