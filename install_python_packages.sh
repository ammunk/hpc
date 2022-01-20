#!/bin/bash

# setup virtual environment
virtualenv --no-download virtual_env
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
