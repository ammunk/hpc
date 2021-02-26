#!/bin/bash

tarball="$1"
workdir="$2"

srun standard_job.sh "${tarball}" "${workdir}"
