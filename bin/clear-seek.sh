#!/bin/bash
# Find file ending in .ts that are a width of 1920p
# in HEVC format, and clear the seek table.
# for a file list:
# cat flist.txt | xargs -L1 mythutil --clearseektable --video

for f in *.ts ; do
    out=$(mediainfo $f)
    res=0
    if ! [[ $out =~ [[:space:]]Width[[:space:]]+:[[:space:]]+1[[:space:]]+920[[:space:]] ]] ; then
        continue
    fi
    if ! [[ $out =~ [[:space:]]Format[[:space:]]+:[[:space:]]+HEVC[[:space:]] ]] ; then
        continue
    fi
    echo -- mythutil --clearseektable --video $f
    mythutil --clearseektable --video $f
done
