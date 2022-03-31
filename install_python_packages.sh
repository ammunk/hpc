#!/bin/bash

########## NOTE ###########

# YOU MUST ENSURE THE RIGHT PIP/PYTHON VERSION IS USED. I.E. that the python cmd
# points to the correct version. THESE SCRIPTS HAVE BEEN TESTED WITH PYTHON3.9

###########################

# setup virtual environment (we explicitly set the python executable to be the
# located whereever the current python executable is located - otherwise
# virtualenv defaults to python2 if available)
virtualenv --python=python --no-download virtual_env # you want to use a different environment creator
source virtual_env/bin/activate
pip install --no-index --upgrade pip

if [ -f Pipfile ]; then
    pip install pipenv
    # we skip locking as it takes quite some time and is redundant
    # note that we use the Pipfile and not the Pipfile.lock here -
    # this is because compute canada's wheels may not include the specific
    # versions specified in the Pipfile.lock file. The Pipfile is a bit less
    # picky and so allows the packages to be installed. Although this could mean
    # slightly inconsistencies in the various versions of the packages.
    time pipenv install --skip-lock
elif [ -f requirements.txt ]; then
    pip install -r requirements.txt
else
    echo "No file specifying python package dependencies."
fi
