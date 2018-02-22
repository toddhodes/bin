#!/bin/tcsh -fx
set wav=$1;
set mp3=$2;
set remotewav=$3;
set remotemp3=$4;
set remotelog=$5;
set lock=$6;

rcp $wav $remotewav;
rsh $remotelog "~/bin/l3enc /tmp/$wav /tmp/$mp3; /bin/rm /tmp/$wav"
rcp $remotemp3 .;
rsh $remotelog "rm /tmp/$mp3";
/bin/rm -f $lock $wav $wav.inf;


