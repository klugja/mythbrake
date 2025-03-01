#!/bin/bash
# Copy input files to current directory output as HEVC
# Input files are assumed to be 1920x1080 pixels
# cd OutputDirectory
# tran1080.sh FileList InputDirectory
# Or maybe something like this:
# tran1080.sh ~/list-1080-hd.txt /mnt/MythRecordings
# After verification, the files can be moved back
# to their original location.
flist=$1
indir=$(readlink -f "$2")

echo File list is $flist
outdir=$(readlink -f $(pwd))
if [[ $indir == $outdir ]] ; then
    echo "Current directory (output directory)"
    echo "cannot be the input directory"
    exit 1
fi
jsonfile=/usr/local/lib/handbrake/HEVC1080p30.json
mkdir -p $outdir/log
exec 2>&1
IFS=$'\n'
list=$(cat $flist)
for f in $list ; do
    b=$(basename -s .mpg $f)
    exec >$outdir/log/$b.txt
    if ! HandBrakeCLI --preset-import-file $jsonfile -Z "HEVC1080p30" -i ${indir}/${f} -o ${outdir}/${f} ; then
        echo $f failed
        echo $f failed >/dev/tty
        exit 1
    else
        echo "Successful result of HandBrakeCli on file $f" | tee /dev/tty
    fi
done
