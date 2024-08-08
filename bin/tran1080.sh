#!/bin/bash
flist=$1
outdir=/home/mythtv/Transcode/pass3
jsonfile=/usr/local/lib/handbrake/HEVC1080p30.json
mkdir -p $outdir/log
exec 2>&1
while read f ; do
    # exec >$outdir/log/$f.txt
    echo $f
    echo "HandBrakeCLI -v10 --preset-import-file $jsonfile -i /mnt/bigr0/store/$f -o /home/mythtv/Transcode/pass3/$f"
    if ! HandBrakeCLI --preset-import-file $jsonfile -Z "HEVC1080p30" -i /mnt/bigr0/store/$f -o /home/mythtv/Transcode/pass3/$f ; then
        echo $f failed
        echo $f failed >/dev/tty
        exit 1
    fi
done < $flist
