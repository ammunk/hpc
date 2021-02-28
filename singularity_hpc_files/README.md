# Singularity applications

We submit [Singularity](https://sylabs.io/) based jobs the same way the virtual
environment based jobs are submitted in terms of the requested computational
resources. That is if your Singularity based job runs python internally, your
jobs effectively will run like a virtual environment. You could then look at the
[REAMDE.md](../virtual_env_hpc_files/README.md) for the virtual environment
based job to see how to run multi-node gpu distributed jobs (although if you use
Lightning you might run into issues).

Submitting a Singularity based job required specifying the path to the container
as well as optionally provided a path to a "work directory" (an empty folder
will be mounted inside the Singularity container using this path),

``` bash
bash job_submitter.sh --singularity-container PATH_TO_CONTAINER --workdir PATH_TO_WORKDIR
```

Most HPCs use Singularity as opposed to Docker due to its advantageous security
features. In a docker container you would have sudo rights, whereas in a
Singularity container you only have sudo right **if** you can call `singularity`
with `sudo`, `sudo singularity ...`. This is obviously prohibited on most hpc
systems, and so Singularity provide certain security guaranteed. While this is
great for the HPC maintainers it causes some practical issues for the user. The
scripts here together with the [Singularity.bld] template is the results of
battling with these issues for several months. Although we will not go into all
the nitty-gritty details here, we will touch upon a few topics which explain
some of the design choices in the scripts and the [Singularity.bld] template.

The main issues stem from the security guarantees Singularity provide. A
Singularity container is build with `sudo` rights and a [Singularity.bld] file

``` bash
sudo singularity build container_name.sif Singularity.bld
```

This means that you only have read access to the filed and directories created
in the Singularity container during the build unless you ensure to change the
permission during build, e.g. `chmod -R -777 some_file_or_directory`. Since
Singularity container are immutable by design (unless you change them with
`sudo` rights), this may seem of little concern at first. However, many
applications generated various temporary files. Those applications would
immediately fail as you do not have write access to the container. Do address
this you would run the Singularity container using the `--writable-tmpf` flag.
This allows file to be created **temporarily** as you run the Singularity
container, and they would be deleted when your application finishes. However, if
any files are written to location created during the build process, you would
still not have write access as you are not running the Singularity container
with `sudo` rights on the hpc. To solve this you either must mount the
appropriate locations in the Singularity container or ensure any user has write
access, hence using `chmod -R -777`.

It seems the `chmod -R -777` would preferable as mounting firstly cause file to
transferred to the host system, and because mounting may overwrite the content
of the mounted directory inside the singularity container. However, if your
application generated files which are relatively large you will quickly run into
an `no space left on device` error even if you used `chmod -R -777` everywhere.
This is because when using `--writable-tmpf` flag the contaienr is only
allocated a small amount of additional (temporary) disk space. This can quickly
become an issue if for instance your application creates a temporary database
(e.g. `sqlite`) or you calculate [fid
scores](https://github.com/mseitzer/pytorch-fid) for your deep learning
applications which requires downloading a copy of a large neural network model.

The solution here is therefore to combine both approaches. The scripts will
automatically [create and mount](#created-and-mounted-folders) different
directories, while the [Singularity.bld] template show how to interact with
these.

## Created and mounted folders

The following directories are automatically created and mounted. Most are
temporary and are deleted upon completion of the job, as they are created in
`${SLURM_TMPDIR}`. Their purpose is to provide for writable directories with
unrestricted disk space (except of that imposed by the host system). 

### Temporary folders

The folders are created on `${SLURM_TMPDIR}` and are not meant to accessed post
job completion. We therefore leave out their names as is only important what
they mount to,

- `${HOME_OVERLAY}:${HOME}`: `HOME_OVERLAY` mounts `${HOME}` inside the
  singularity container. This will wipe anything inside `${HOME}` and you should
  not place any code inside `/home/${USER}/` during the build process. `${HOME}`
  is considered the "working directory by default" and if `--workdir` is not
  provided when submitting the job, you probably wont to copy your source code
  to `${HOME}` when starting your Singularity application. See [Singularity.bld]
- `${DB}:/db`: `/db` is a directory where you could place e.g. a database
- `${TMP}:/tmp`: let `/tmp` function as an actual `/tmp` directory
- `${WORKDIR_OVERLAY}:${workdir}`: `${workdir}` is a user specified "working
  directory", meant to be used if you do not want this to be `${HOME}`
  
### Directories accessible after job completion

For each job the scripts create a directory on `${SCRATCH}`, which can be found
at
`scratch_storage="${scratch_dir}/${exp_name}/singularity_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"`.

This will be mounted as

- `${scratch_storage}:/scratch_storage`

If you application stores checkpoints or other results you should create those
in `/scratch_storage`. You then find these results on the host machine in
`${scratch_storage}`.

## Accessing data required by the application

It is likely that your application needs access to some kind of data. The
current version of the scripts assumes you want to first transfer the data onto
the local nodes. The script will automatically mount
`${SLURM_TMPDIR}/data:/data`. As specified in [../REAMDE.md], to transfer data
to `${SLURM_TMPDIR}` you need to use the `--data` flag when submitting your job.
However, since the scripts mount `${SLURM_TMPDIR}/data` to `/data` inside the
container, you should have the following structure on `${SCRATCH}`


``` text
${SCRATCH}
├── project_root
│   └── data
│       ├──dataset1
│       ├──dataset2
│       │ 
.       .
.       . other files in data
.       .
.
. other files on scratch
.
```

You could then submit your job as

``` bash
bash job_submitter.sh --singularity-container path_to_container --data data
```

which would transfer the entire `${SCRATCH}/project_root/data` to
`${SLURM_TMPDIR}`. If you only want to transfer a subset of the content in
`${SCRATCH}/project_root/data` you could instead do

``` bash
bash job_submitter.sh --singularity-container path_to_container --data data/dataset1
```
## The Singularity file

We provide a Singularity file [tempalte][Singularity.bld] to see how to one can
use `chmod -R -777` and move source code to the mounted `${workdir}` inside the
container when the job is running. This file needs to be adjusted to your
specific application. Note that the scripts make no assumptions about how you
build your container and only deals with mounting directories and running the
container.

## Providing experiment arguments

Your command provided in [experiment_configurations.txt] (or [your own]) will be
provided to your singularity container as is. For instance, if you want to run
`python main.py` within you Singularity container, the
[experiment_configurations.txt] would look like this

``` bash
# experiment_configurations.txt

python main.py
```

Under the hood the Singularity [script] calls (simplified)

``` bash
singularity run container_name.sif "$cmd"
```

where `$cmd` is expanded to the commands found in
[experiment_configurations.txt]. In pratice [script] calls `singularity` with a
series of additional options as well as mounting different directories.

### `wandb` sweep

To perform a `wandb` sweep, simply edit the [experiment_configurations.txt] file

``` bash
# experiment_configurations.txt
wandb agent --count 1 WANDB_USERNAME/PROJECT_NAME/SWEEP_ID
```
and execute

```bash
bash job_submitter.sh --job-type sweep --singularity-container PATH_TO_CONTAINER
```

### Adding your own (additional) configuration files

You can also create your own configuration files. Just provide the path to the
job submitter,

``` bash
bash job_submitter.sh --configs PATH_TO_YOU_CONFIG_FILE
```

# TODO

- [ ] Allow to mount to data directory located on scratch


[experiment_configurations.txt]: (../experiment_configurations.txt) 
[your own]: (#adding-your-own-(additional)-configuration-files)
[script]: (standard_job.sh)
[Singularity.bld]: (Singularity.bld)
