#!/bin/sh
# Copyright (c) 2001  Dustin Sallings <dustin@spy.net>
#
# $Id: filemonitor,v 1.12 2002/05/22 00:47:50 dustin Exp $

# Search for START to find the beginning of the script (after functions)

SAVEDIR="/var/filemon"
IGNORELIST="/usr/local/etc/filemon.ignore"

DEBUG=:

# Save a file to our save directory
savefile() {
	file="$1"
	STMP="$2"
	basefile="$3"

	rm -f "$STMP/$basefile"
	# Lock 'em if you got 'em
	if [ -f "$STMP/RCS/$basefile,v" ]
	then
		rcs -q -l "$STMP/$basefile"
	fi
	# OK, now copy and checkin
	cp "$file" "$STMP/$basefile" > /dev/null 2>&1
	if [ -f "$STMP/$basefile" ]
	then
		if [ ! -d "$STMP/RCS" ]
		then
			mkdir -p "$STMP/RCS"
		fi
		# Check it in, this unlocks it
		echo "New file" | ci -q -mAutosave "$STMP/$basefile"
	else
		echo "Could not copy $file"
	fi
}

# Is this a file we care to keep up with?
monitoredfile() {
	file="$1"
	rv=0

	if [ -f "$IGNORELIST" ]
	then
		egrep -v "^#" "$IGNORELIST" | fgrep "$file" > /dev/null
		if [ $? -eq 0 ]
		then
			$DEBUG "found $file in $IGNORELIST"
			rv=1
		fi
	fi

	$DEBUG "Returning $rv for $file"
	return $rv
}

# What to do when we find a directory
processdir() {

	DIR=$1
	$DEBUG "Processing $DIR"
	STMP=$SAVEDIR$DIR
	if [ ! -d $STMP ]
	then
		$DEBUG $STMP does not exist
		mkdir -p $STMP
	fi

	# Look at everything in our directory
	for file in "$1"/*
	do
		# Only monitor the files, not other crap that might be in there
		if [ -f "$file" ]
		then
			# Just the filename
			basefile="`basename "$file"`"
			$DEBUG "$basefile in $DIR is a file"

			if monitoredfile "$file"
			then
				# If we've got the file in RCS already, compare it.
				if [ -f "$STMP/RCS/$basefile,v" ]
				then

					# Make sure we're working on the RCS version of the file
					rm -f "$STMP/$basefile"
					co -kb -q "$STMP/$basefile"

					# Compare them
					diff "$STMP/$basefile" "$file" > /dev/null
					if [ $? -eq 1 ]
					then
						echo "*** $file has changed ***"
						echo ""
						diff "$STMP/$basefile" "$file"
						echo ""
						savefile "$file" "$STMP" "$basefile"
					fi

					# We don't need you, anymore
					rm -f "$STMP/$basefile"
				else
					echo "$file was added"
					savefile "$file" "$STMP" "$basefile"
				fi # Got the file/don't got the file
			else
				$DEBUG "$file is not monitored"
			fi # Monitoring the file
		fi # It's a file
	done
}

# Called once for each directory
processdirs() {
	while read DIR
	do
		processdir "$DIR"
	done
}

# START

# Every good program needs a good umask
umask 77

OPTS="xd:i:"

# First, run getopt to get the return code for testing
getopt "xd:i:" $* > /dev/null
if [ $? != 0 ]
then
	echo "Usage:  $0 [-x] [-i ignorelist] [-d savedir] /path1 /path2"
	echo "  -i should point to a file containing a list of files to ignore"
	echo "  -d points to the directory in which state will be saved"
	echo "  -x is for debug"
	exit 1
fi

# Now we run getopt again to get the actual arguments.
set -- `getopt "xd:i:" $*`

# read through the arguments.
for i in $*
do
	case $i in
		-d)
			SAVEDIR=$2
			$DEBUG "SAVEDIR set to $SAVEDIR"
			shift 2
		;;
		-i)
			IGNORELIST=$2
			$DEBUG "IGNORELIST set to $IGNORELIST"
			shift 2
		;;
		-x)
			DEBUG=echo
			shift
		;;
	esac
done

# Get rid of the --
shift

# Make sure there's at least one directory to monitor
if [ $# -lt 1 ]
then
	echo "You must give at least one directory to check"
	exit
fi

# Process the rest of the arguments as directories.
for DIR in "$@"
do
	# Make sure the directory starts with /
	case "$DIR" in
		/*)
			# This is the good case
			:
		;;
		*)
			echo "Dir doesn't start with a slash"
			exit
		;;
	esac

	# Find all directories not named RCS and process them
	find $DIR -type d ! -name RCS -print | processdirs
done
