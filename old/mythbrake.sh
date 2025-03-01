#!/bin/bash
# Save this as mythbrake.sh and make the file executable
# Written by Ares Drake, ares.drake@gmail.com
# Licenced under GPL v3
# This Script shall be called as MythTV user job. It transcodes the DVB recordings (mpeg files) using Handbrake. It first checks whether the recording is HDTV. If so it will be reencoded with HEVC to save space. SDTV will have commercials cut out if necessary and will then be transcoded to HEVC.
#
#USAGE:######################
# This Script shall be called as a MythTV user job like as follows:
# /path/to/mythbrake.sh "%DIR%" "%FILE%" "%CHANID%" "%STARTTIMEUTC%" "%TITLE%" "%SUBTITLE%" "%CATEGORY%"
#############################
#
#
#REQUIREMENTS################
# You need to have the following programs installed:
# mediainfo: http://mediainfo.sourceforge.net/
# handbrake with dependencies: http://www.handbrake.fr
# Installation of these is covered on their sites
#############################


######SOME CONSTANSTS FOR USER EDITING######
############################################
logdir="/var/log/mythtv/transcodelogs" #change to your needs for logs
errormail="youremail@adress.com" # this email address will be informed in case of errors
outdir="/home/mythtv/Transcode" # specify directory where you want the transcoded file to be placed
#Audio track (language) selection, your values must match the output syntax of mediainfo
#check "mediainfo --Inform="Audio;%Language/String% yoursourcefile.mpg" in the terminal for syntax
lang_1="English" #Primary language you want to keep
lang_2="German" #Secondary language you want to keep, use "none" to skip, quaa is original language, wich is English most of the time
lang_3="French" #Thid language you want to keep, use "none" to skip
lang1_name="English" #This is the label of the 1st audio stream inside the final video file
lang2_name="German" #This is the label of the 2nd audio stream inside the final video file
lang3_name="French" #This is the label of the 3rd audio stream inside the final video file
######END constants for user editing######


######DEFINE SOME BASIC VARIABLES######
#######################################
scriptstarttime=$(date +%F-%H%M%S)
mythrecordingsdir="$1" # specify directory where MythTV stores its recordings
file="$2"
# using sed to sanitize the variables to avoid problematic file names, only alphanumerical, space, hyphen and underscore allowed, other characters are transformed to underscore
subtitle="$(echo "$6" | sed 's/[^A-Za-z0-9_ -]/_/g')"
title="$(echo "$5" | sed 's/[^A-Za-z0-9_ -]/_/g')"
category="$(echo "$7" | sed 's/[^A-Za-z0-9_ -]/_/g')"
chanid="$3"
starttime="$4"
if [ -z "$category" ]
then
category="Unknown" #name for unknown category, Unbekannt is German for unknown
fi
logfile="$logdir/$scriptstarttime-$title.log"
touch "$logfile"
chown mythtv:mythtv "$logfile"
chmod a+rw "$logfile"
filename="$title.mp4" # can be customized
if [ -f "$outdir/$filename" ]
 # do not overwrite outfile, if already exists, change name
 then
 filename="$title-$scriptstarttime.mp4"
fi
outfile="$outdir/$filename"
let lang_1_count=0
let lang_2_count=0
let lang_3_count=0
lang_1_track=""
lang_2_track=""
lang_3_track=""
######Variables finished

######DO SOME LOGGING######
###########################
echo "Transcode job $title starting at $scriptstarttime" >> "$logfile"
echo "Original file: $mythrecordingsdir/$file" >> "$logfile"
echo "Target file: $outfile" >> "$logfile"
echo "ChanId: $chanid Time: $starttime" >> "$logfile"

######SOURCEFILE CHECK######
############################
if [ ! -f "$mythrecordingsdir/$file" ]
then
    #source file does not exist
    scriptstoptime=$(date +%F-%H%M%S)
    echo "Error at $scriptstoptime: Source file not found " >> "$logfile"
    echo "Maybe wrong path or missing permissions?" >> "$logfile"
    mail -s "Mythtv Sourcefile Error on $HOSTNAME" "$errormail" < "$logfile"
    mv "$logfile" "$logfile-FAILED"
    exit 1
fi

######MEDIAINFO CHECK######
###########################
fullmediainfo=(mediainfo $mythrecordingsdir/"$file")
if [ $? != 0 ]
    # There were errors with Mediainfo.
    then
    scriptstoptime=$(date +%F-%H%M%S)
    echo "Error prior to encoding at $scriptstoptime" >> "$logfile"
    echo "Mediainfo encountered an error. Maybe mediainfo is not installed, or not in your path" >> "$logfile"
    echo "Mediainfo encountered an error. Maybe mediainfo is not installed, or not in your path"
    mail -s "Mythtv Mediainfo Error on $HOSTNAME" "$errormail" < "$logfile"
    mv "$logfile" "$logfile-FAILED"
    exit 1
    else
    echo "Mediainfo Run successful." >> "$logfile"
  fi




#######ANALAYZE AUDIO TRACKS AND DO LANGUAGE SELECTION######
############################################################
acount=$(mediainfo --Inform="General;%AudioCount%" "$mythrecordingsdir/$file")
#acount=number of audio tracks present in source file

#Read all values into arrays
bitrate="$(mediainfo --Inform="Audio;:%BitRate%" "$mythrecordingsdir/$file")"
IFS=':' read -ra ARBITR <<< "$bitrate"
language="$(mediainfo --Inform="Audio;:%Language/String%" "$mythrecordingsdir/$file")"
IFS=':' read -ra ARLANG <<< "$language"
channels="$(mediainfo --Inform="Audio;:%Channel(s)%" "$mythrecordingsdir/$file")"
IFS=':' read -ra ARCHAN <<< "$channels"
acodec="$(mediainfo --Inform="Audio;:%Format%" "$mythrecordingsdir/$file")"
IFS=':' read -ra ARCODEC <<< "$acodec"
#Finished building arrays

echo "Array built successful, starting looping over audio tracks. There are $acount tracks, so we loop $acount times." >> "$logfile"

for (( I=1; I <= "$acount"; I++ ))
do
#loop through all tracks, currently active track is $I
#${ARBITR[$I]},${ARLANG[$I]},${ARCHAN[$I]},${ARCODEC[$I]} gives values for track $I
echo "loop number $I." >> "$logfile"

#select track for first language
currentlang=${ARLANG[$I]}
if [ "$currentlang" == "$lang_1" ]
then
	echo -n "track $I matching $lang1_name" >> "$logfile"
	let "lang_1_count += 1" 	#let $lang_1_count = $lang_1_count+1
	if [ $lang_1_count -eq 1 ]
	then
	#if this is the first track with desired language, we use it.
	echo " and is the first track matching" >> "$logfile"
	lang_1_track=$I
	let lang_1_chan="${ARCHAN[$I]}"
	lang_1_codec="${ARCODEC[$I]}"
	elif [ "${ARCHAN[$I]}" -gt "${ARCHAN[$lang_1_track]}" ]
	then
	echo " and is better than previous match" >> "$logfile"
	#there is already a track with the same desired language but this current track
	#has more channels, so we use this one instead of the previous track.
	lang_1_track=$I
	let lang_1_chan=${ARCHAN[$I]}
	lang_1_codec="${ARCODEC[$I]}"
	fi
fi
echo "Audio track1 iteration succesfull" >> "$logfile"


#select track for second language
if [ "$lang_2" != "none" ]
then
  if [ "$currentlang" == "$lang_2" ]
  then
	  echo -n "track $I matching $lang2_name" >> "$logfile"
	  let "lang_2_count += 1"
	  if [ $lang_2_count -eq 1 ]
	  then
	  #if this is the first track with desired language, we use it.
	  echo " and is the first track matching" >> "$logfile"
	  let lang_2_track=$I
	  let lang_2_chan="${ARCHAN[$I]}"
	  lang_2_codec="${ARCODEC[$I]}"
	  elif [ "${ARCHAN[$I]}" -gt "${ARCHAN[$lang_2_track]}" ]
	  then
	  echo " and is better than previous match" >> "$logfile"
	  #there is already a track with the same desired language but this current track
	  #has more channels, so we use this one instead of the previous track.
	  let lang_2_track=$I
	  let lang_2_chan=${ARCHAN[$I]}
	  lang_2_codec="${ARCODEC[$I]}"
	  fi
fi
fi
echo "Audio track2 iteration succesfull" >> "$logfile"


if [ "$lang_3" != "none" ]
then
#select track for third language
if [ "$currentlang" == "$lang_3" ]
then
	echo -n "track $I matching $lang3_name" >> "$logfile"
	let "lang_3_count += 1"
	if [ $lang_3_count -eq 1 ]
	then
	#if this is the first track with desired language, we use it.
	echo " and is the first track matching" >> "$logfile"
	let lang_3_track=$I
	let lang_3_chan="${ARCHAN[$I]}"
	lang_3_codec="${ARCODEC[$I]}"
	elif [ "${ARCHAN[$I]}" -gt "${ARCHAN[$lang_3_track]}" ]
	then
	echo " and is better than previous match" >> "$logfile"
	#there is already a track with the same desired language but this current track
	#has more channels, so we use this one instead of the previous track.
	let lang_3_track=$I
	let lang_3_chan="${ARCHAN[$I]}"
	lang_3_codec="${ARCODEC[$I]}"
	fi

fi
fi
echo "Audio track3 iteration succesfull" >> "$logfile"
done

echo "Audio track iteration succesfull" >> "$logfile"
#okay, how may tracks to include in the outfile now?
let totallangcount=($lang_1_count + $lang_2_count + $lang_3_count)
if [ $totallangcount -eq 0 ]
    # No suitable audio track found.
    then
    scriptstoptime=$(date +%F-%H%M%S)
    echo "Audio track error at $scriptstoptime" >> "$logfile"
    echo "The script was unable to find a matching audio track, aborting." >> "$logfile"
    mail -s "Mythtv Audio Track Error on $HOSTNAME" "$errormail" < "$logfile"
    mv "$logfile" "$logfile-FAILED"
    exit 1
    else
    echo "Audio selection successful." >> "$logfile"
fi



echo "Total number of tracks selected: $totallangcount" >> "$logfile"


###Now generate Handbrake commands from the above####





if [ $lang_1_count -ge 1 ]
	then
	echo "Selected track $lang_1_track for $lang_1" >> "$logfile"
	audiotacks="$lang_1_track" #Handbrake_CLI -a
	if [ $lang_1_chan -gt 2 ]
	# more than 2 channels present, pass through track without transcoding,perfect quality
		then
		audioname="$lang1_name-Surround" #Handbrake_CLI -A
		audiocodec="copy" #Handbrake_CLI -E
		audiobitrate="auto" #Handbrake_CLI -B
		audiodownmix="auto" #Handbrake_CLI -6
		else
		audioname="$lang1_name-Stereo"
		audiocodec="faac"
		audiobitrate="128"
		audiodownmix="stereo"
	fi
	else
	echo "No track found for $lang_1 = $lang1_name" >> "$logfile"
	fi
if [ $lang_2_count -ge 1 ]
	then
	echo "Selected track $lang_2_track for $lang_2" >> "$logfile"

		if [ -z "$audiotacks" ]
		#no track for first language present
		then
		audiotacks="$lang_2_track" #Handbrake_CLI -a
			if [ $lang_2_chan -gt 2 ]
			# more than 2 channels present
			#pass through track without transcoding,perfect quality
			then
			audioname="$lang2_name-Surround" #Handbrake_CLI -A
			audiocodec="copy" #Handbrake_CLI -E
			audiobitrate="auto" #Handbrake_CLI -B
			audiodownmix="auto" #Handbrake_CLI -6
			else
			audioname="$lang2_name-Stereo"
			audiocodec="faac"
			audiobitrate="128"
			audiodownmix="stereo"
			fi
		else
		#first track present, append
		audiotacks="$audiotracks,$lang_2_track" #Handbrake_CLI -a
			if [ $lang_2_chan -gt 2 ]
			# more than 2 channels present
			#pass through track without transcoding,perfect quality
			then
			audioname="$audioname,$lang2_name-Surround" #Handbrake_CLI -A
			audiocodec="$audiocodec,copy" #Handbrake_CLI -E
			audiobitrate="$audiobitrate,auto" #Handbrake_CLI -B
			audiodownmix="$audiodownmix,auto" #Handbrake_CLI -6
			else
			audioname="$audioname,$lang2_name-Stereo"
			audiocodec="$audiocodec,faac"
			audiobitrate="$audiobitrate,128"
			audiodownmix="$audiodownmix,stereo"
			fi
		fi
	else
	echo "No track found for $lang_2 = $lang2_name" >> "$logfile"
	fi
if [ $lang_3_count -ge 1 ]
	then
	echo "Selected track $lang_3_track for $lang_3" >> "$logfile"
		if [ -z "$audiotacks" ]
		#no track for first or second language present
		then
		audiotacks="$lang_3_track" #Handbrake_CLI -a
			if [ $lang_3_chan -gt 2 ]
			# more than 2 channels present
			#pass through track without transcoding,perfect quality
			then
			audioname="$lang3_name-Surround" #Handbrake_CLI -A
			audiocodec="copy" #Handbrake_CLI -E
			audiobitrate="auto" #Handbrake_CLI -B
			audiodownmix="auto" #Handbrake_CLI -6
			else
			audioname="$lang3_name-Stereo"
			audiocodec="faac"
			audiobitrate="128"
			audiodownmix="stereo"
			fi
		else
		#previous track present, append
		audiotacks="$audiotracks,$lang_3_track" #Handbrake_CLI -a
			if [ $lang_3_chan -gt 2 ]
			# more than 2 channels present
			#pass through track without transcoding,perfect quality
			then
			audioname="$audioname,$lang3_name-Surround" #Handbrake_CLI -A
			audiocodec="$audiocodec,copy" #Handbrake_CLI -E
			audiobitrate="$audiobitrate,auto" #Handbrake_CLI -B
			audiodownmix="$audiodownmix,auto" #Handbrake_CLI -6
			else
			audioname="$audioname,$lang3_name-Stereo"
			audiocodec="$audiocodec,faac"
			audiobitrate="$audiobitrate,128"
			audiodownmix="$audiodownmix,stereo"
			fi
		fi
	else
	echo "No track found for $lang_3 = $lang3_name" >> "$logfile"
	fi

echo "Finished Audio Selection" >> "$logfile"
#################FINISHED AUDIO TRACK SELECTION############

echo "$audiotacks, $audioname, $audiocodec, $audiobitrate, $audiodownmix"
echo "$audiotacks, $audioname, $audiocodec, $audiobitrate, $audiodownmix" >> "$logfile"
#HandBrakeCLI -q 19.0 -e x265 -r 25 -a $audiotacks -A $audioname -E $audiocodec -B $audiobitrate -6 $audiodownmix -f mp4 --crop 0:0:0:0 -d -m -x b-adapt=2:rc-lookahead=50:ref=3:bframes=3:me=umh:subme=8:trellis=1:merange=20:direct=auto -i "$mythrecordingsdir/$file" -o "$outfile" -4 --optimize 2>> "$logfile"

####################
#get width: you need mediainfo installed, see mediainfo.sourceforge.net
width=$(mediainfo --Inform="Video;%Width%" "$mythrecordingsdir/$file")

##############################################################



### Transcoding starts here, in 3 differend versions: HDTV w/o commercials, SDTV w/ and w/o commercials.


# width >=1280
# currently this can only be ARD HD, ZDF HD or ARTE HD, so no commercials
# Userjob for HDTV: Re-Encode in AVC HEVC: saves space, but keeps HEVC, x265 via HandbrakeCLI
if [ $width -ge 1280 ]
  then
  echo "Userjob HD-TV starts because of with of $width" >> "$logfile"
HandBrakeCLI --multi-pass -q 24 -e x265 -r 25 -a "$audiotacks" -A "$audioname" -E "$audiocodec" -B "$audiobitrate" -6 "$audiodownmix" -f mp4 --crop 0:0:0:0 -d -m -x b-adapt=2:rc-lookahead=50:ref=3:bframes=3:me=umh:subme=8:trellis=1:merange=20:direct=auto -i "$mythrecordingsdir/$file" -o "$outfile" -4 --optimize 2>> "$logfile"
  if [ $? != 0 ]
	# There were errors in the Handbrake Run.
	then
	scriptstoptime=$(date +%F-%H%M%S)
	echo "Transcoding-Error at $scriptstoptime" >> "$logfile"
	echo "Interrupted file $outfile" >> "$logfile"
	echo "###################################" >> "$logfile"
	echo $fullmediainfo >> "$logfile"
	echo "###################################" >> "$logfile"
	outmediainfo=(mediainfo "$outfile")
	echo $outmediainfo >> "$logfile"
	echo "###################################" >> "$logfile"
	mail -s "Mythtv Transcoding Error on $HOSTNAME" "$errormail" < "$logfile"
        mv "$logfile" "$logfile-FAILED"
	exit 1
   else
	echo "Transcode Run successfull." >> "$logfile"
	file "$outfile" >> "$logfile"
  fi
#check if outfile exists
  if [ ! -f "$outfile" ];
	then
	scriptstoptime=$(date +%F-%H%M%S)
	echo "Output-Error at $scriptstoptime" >> "$logfile"
	echo "Ausgabedatei $outfile existiert nicht"  >> "$logfile"
	echo "###################################" >> "$logfile"
	echo $fullmediainfo >> "$logfile"
	echo "###################################" >> "$logfile"
	outmediainfo=(mediainfo "$outfile")
	echo $outmediainfo >> "$logfile"
	echo "###################################" >> "$logfile"
	mail -s "Mythtv Ausgabedatei Error on $HOSTNAME" "$errormail" < "$logfile"
        mv "$logfile" "$logfile-FAILED"
        exit 1
  fi


#width <= 720
elif [ $width -le 720 ]
  then
 # this is SDTV, so it could be either with or without commercials. We check for commercials by comparing to ChanID list.

    if [
    #ChanID without commercials
    $chanid == 3007 -o  #3sat
    $chanid == 29014 -o #zdf neo
    $chanid == 30014 -o #zdf neo
    $chanid == 30107 -o #BayrFS
    $chanid == 29110 -o #BR
    $chanid == 30110 -o #BR
    $chanid == 30113 -o #SWR-BW
    $chanid == 30111 -o #WDR
    $chanid == 30230 -o #MDR
    $chanid == 30206 -o #rbb
    $chanid == 29205 -o #rbb
    $chanid == 29206 -o #rbb
    $chanid == 29205 -o #rbb
    $chanid == 29486 -o #SR
    $chanid == 30107 -o #BayrFS
     ]
    # better option would be to pull the commercial-free flag from the database, but
    # then I got advised against manual access to the database when using a language
    # such as bash with no mysql support.
      then
      #This is a channel without commercials, encoding to X265
      echo "Userjob SD-TV without Commercials: STARTS" >> "$logfile"
HandBrakeCLI --multi-pass -q 24 -e x265 -r 25 -a "$audiotacks" -A "$audioname" -E "$audiocodec" -B "$audiobitrate" -6 "$audiodownmix" -f mp4 --crop 0:0:0:0 -d -m -x b-adapt=2:rc-lookahead=50:ref=3:bframes=3:me=umh:subme=8:trellis=1:merange=20:direct=auto -i "$mythrecordingsdir/$file" -o "$outfile" -4 --optimize 2>> "$logfile"
      if [ $? != 0 ]
	# There were errors in the Handbrake Run.
	then
	scriptstoptime=$(date +%F-%H%M%S)
	echo "Transcoding-Error at $scriptstoptime" >> "$logfile"
	echo "Broken File $outfile" >> "$logfile"
	echo "###################################" >> "$logfile"
	echo $fullmediainfo >> "$logfile"
	mail -s "Mythtv Transcoding Error on $HOSTNAME" "$errormail" < "$logfile"
        mv "$logfile" "$logfile-FAILED"
	exit 1
	else
	echo "Transcode Run successful." >> "$logfile"
      fi

    else
      # We have a channel with commercials, so flag & cut them out first.
      echo "Userjob SD-TV with commercials: START" >> "$logfile"
      /usr/bin/mythcommflag -c "$chanid" -s "$starttime" --gencutlist
      /usr/bin/mythtranscode --chanid "$chanid" --starttime "$starttime" --mpeg2 --honorcutlist
      /usr/bin/mythcommflag --file "$file" --rebuild
      #Finished commercial cutting, following is encoding as above

      #SD-TV Userjob is encoding to MPEG4 ASP aka DivX aka Xvid via FFMPEG via HandBrakeCLI
      # $SDCCMDLINE is the commandline for SDtv-Commercials
      SDCCMDLINE='/usr/bin/HandBrakeCLI --multi-pass -q 24 -r 25 -a $audiotacks -A $audioname -E $audiocodec -B $audiobitrate -6 $audiodownmix -f mp4 --crop 0:0:0:0 -d -m -i "$mythrecordingsdir/$file" -o "$outfile" --optimize 2>> "$logfile"'

      echo "Commandline: $SDCCMDLINE" >> "$logfile"
      HandBrakeCLI --multi-pass -q 24 -r 25 -a "$audiotacks" -A "$audioname" -E "$audiocodec" -B "$audiobitrate" -6 "$audiodownmix" -f mp4 --crop 0:0:0:0 -d -m -i "$mythrecordingsdir/$file" -o "$outfile" --optimize  2>> "$logfile"

      if [ $? != 0 ]
	# There were errors in the Handbrake Run.
	then
	scriptstoptime=$(date +%F-%H%M%S)
	echo "Transcoding-Error at $scriptstoptime" >> "$logfile"
	echo "Broken File $outfile" >> "$logfile"
	echo "###################################" >> "$logfile"
	echo $fullmediainfo >> "$logfile"
	mail -s "Mythtv Transcoding Error on $HOSTNAME" "$errormail" < "$logfile"
        mv "$logfile" "$logfile-FAILED"
	exit 1
	else
	echo "Transcode Run successful." >> "$logfile"
      fi
    fi

#720<width<1280 or error getting width: dunno whats going on here, abort
else
    echo "Error: 720<width<1280, undefined condition, aborting" >> "$logfile"
    echo "###################################" >> "$logfile"
    echo $fullmediainfo >> "$logfile"
    mail -s "Mythtv Transcoding Error on $HOSTNAME" "$errormail" < "$logfile"
    mv "$logfile" "$logfile-FAILED"
    exit 1
fi

  scriptstoptime=$(date +%F-%H%M%S)
  echo "Successfully finished at $scriptstoptime" >> "$logfile"
  echo "Transcoded file: $outfile" >> "$logfile"

#Transcoding now done, following is some maintenance work
chown mythtv:mythtv "$outfile"


exit 0

