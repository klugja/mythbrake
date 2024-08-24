#!/bin/bash
# Find file ending in .mpg that are a width of 1920p
# Throw out files that are already in HEVC format.
# First change to directory withn *.MPG or *.TS files.
# cd MythRecordingsDirectory
# find-hd1080.sh >~/list-hd-1080.txt

for f in *.mpg *.ts ; do
    out=$(mediainfo $f)
    res=0
    if ! [[ $out =~ [[:space:]]Width[[:space:]]+:[[:space:]]+1[[:space:]]+920[[:space:]] ]] ; then
        continue
    fi
    if [[ $out =~ [[:space:]]Format[[:space:]]+:[[:space:]]+HEVC[[:space:]] ]] ; then
        continue
    fi
    echo $f
done
