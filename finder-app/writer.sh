#!/bin/sh

if [ "$#" -ne 2 ]; then
    printf 'Error: usage: %s writefile writestr\n' "$0" >&2
    exit 1
fi

writefile=$1
writestr=$2

if ! mkdir -p -- "$(dirname -- "$writefile")"; then
    printf 'Error: could not create parent directory for "%s".\n' "$writefile" >&2
    exit 1
fi

if ! printf '%s\n' "$writestr" > "$writefile"; then
    printf 'Error: could not write file "%s".\n' "$writefile" >&2
    exit 1
fi