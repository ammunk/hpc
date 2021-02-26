# Virtual environment applications

## `requirements.txt` or `Pipfile`

The scripts will automatically create the virtual environment in `${source_dir}`
based on either a `${source_dir}/requirements.txt` or `${source_dir}/Pipfile`
file. If both are present the `Pipfile` will take precedence. The `Pipfile` are
the equivalent of a `requirements.txt` file but used by
[pipenv](https://pipenv.pypa.io/en/latest/) for creating and managing a
virtual environment.

## Providing experiment arguments

When doing a `wandb` sweep, the [sweeper.yml] file specifies the executed
commands. Otherwise you simply need to create a file (or just edit the
[experiment_configurations.txt] file) within
which the commands passed to the `python` execution call.

For instance if you locally would run your experiment As

```bash
python main.py --train --batch_size 6
```

you could edit the
[experiment_configurations.txt] to contain

``` text
# experiment_configurations.txt

main.py --train --batch_size 6
```

or

``` text
# experiment_configurations.txt

main.py \
--train \
--batch_size 6
```
If you create you own configuration file, remember to provide it's path to the job submitter,

``` bash
bash job_submitter.sh --configs PATH_TO_YOU_CONFIG_FILE
```

[experiment_configurations.txt]: (../experiment_configurations.txt) 
[sweeper.yml]: (../sweeper.yml) 
