#!/usr/bin/env bash
set -euo pipefail

if [[ -f "$1" ]]; then
    arguments="$(sed -ne '/^parameters/,/^command/{//!p}' "$1" | \
        sed -nr '/ *(values|-)/p' | tr -d " " | tr -d '\n' | sed 's/values:/;/g' | tr ';' ' ')"

    grid_size=1

    for a in $arguments;
    do
        with_delimiter="$(echo $a | tr '-' ' ')"
        with_delimiter=( $with_delimiter )
        grid_size=$((grid_size*${#with_delimiter[@]}))
    done
    echo $grid_size
else
    echo "Either no argument was given or file does not exist" >&2; exit 1
fi
