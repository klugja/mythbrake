# mythbrake Transcoder using Handbrake
## Website: https://www.mythtv.org/wiki/Mythbrake
Original script uses x264. Updated to x265.
# Usage
1. lib and bin files should be copied to
/usr/local/bin and /usr/local/lib.

2. Then find all the 1920x1080 files to convert
to HEVC. Input files are assumed to be
AC-3. Audio is not altered. Script writes to stdout,
so save to a file.

3. Run HandBrakeCLI from script.  First parameter is
the file list created in step2. 2nd parameter is the
location of the files to re-compress.  Current directory
is the output.
