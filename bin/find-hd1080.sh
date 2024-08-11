#!/bin/bash
# Find file ending in .mpg that are a width of 1920p
# These are all MPEG files.
# First change to directory withn *.MPG files.
# cd MythRecordingsDirectory
# find-hd1080.sh >~/list-hd-1080.txt
for f in *.mpg ; do
    out=$(mediainfo $f | grep Width)
    if [[ $out =~ :[[:space:]]+1[[:space:]]+920[[:space:]] ]] ; then
        echo $f
    fi
done
