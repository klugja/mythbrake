#!/bin/bash
# Find file ending in .mpg that are a width of 1920p
# These are all MPEG files.
cd /mnt/bigr0/store
for f in *.mpg ; do
    out=$(mediainfo $f | grep Width)
    if [[ $out =~ :[[:space:]]+1[[:space:]]+920[[:space:]] ]] ; then
        echo $f
    fi
done
