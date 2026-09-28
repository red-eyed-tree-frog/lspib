#!/bin/sh

if [ "$#" -ne 2 ]; then
    printf '%s filesdir searchstr\n' "$0" >&2
    exit 1
fi

filesdir=$1
searchstr=$2

if [ ! -d "$filesdir" ]; then
    printf 'Error: "%s" is not a directory.\n' "$filesdir" >&2
    exit 1
fi

case "$filesdir" in
    /*) ;;
    *) filesdir=./$filesdir ;;
esac

files=$(find "$filesdir" -type f -exec printf '1\n' \; | wc -l)

matches=$(find "$filesdir" -type f -exec grep -F -c -h -a -- "$searchstr" {} + |
    awk '{ total += $1 } END { print total + 0 }')

printf 'The number of files are %s and the number of matching lines are %s\n' \
    "$files" "$matches"