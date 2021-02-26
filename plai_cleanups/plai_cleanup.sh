#!/bin/bash

PLAI_TMPDIR="/scratch-ssd/"
cd $PLAI_TMPDIR
echo "WHATS IN /scratch-ssd BEFORE CLEANUP:" && ls -la
# see https://stackoverflow.com/questions/2937407/test-whether-a-glob-has-any-matches-in-bash
if test -n "$(find -maxdepth 1 -name "${USER}*" -print -quit)"; then
    rm -rf ${USER}*
    echo "WHATS IN /scratch-ssd AFTER CLEANUP:" && ls -la
else
    echo "Nothing to delete"
fi
