#!/usr/bin/perl

# List of hosts we copy files to for encoding
@hosts=("u40","u41","u42","u43","u44","u45");
#@hosts=("u50","u51");

# By convention, touch files indicating that that host is being used to decode already


for($f=1; $f<=35; $f++){
    # Copy the track from the CD
    if(system("cdda2wav -D /dev/cdrom -t$f track$f.wav")!=0){
	die;
    }

    # Find a host that isn't decoding
    $found=0;
    do{
      HOST:
	for($i=0; $i<=$#hosts; $i++){
	    $lockfile="$hosts[$i].lock";
	    if (!(-e $lockfile)){
		print STDERR "using $hosts[$i]\n";
		system("touch $hosts[$i].lock");
		$found=1;
		$host=$i;
	    }
	    last HOST if $found;
	}
	if (!$found){
	    sleep(30);
	}
    } while (!$found);

    # Now found a host, copy the wav file to it, encode it, and copy the result back
    $remotewav="$hosts[$host]:/tmp/track$f.wav";
    $remotemp3="$hosts[$host]:/tmp/track$f.mp3";
    $remotelogin="$hosts[$host]";
    $log="$hosts[$host]_$f.log";

#    print STDERR "$remotewav $remotemp3 $remotelogin $log\n";

    system("track2mp3.csh track$f.wav track$f.mp3 $remotewav $remotemp3 $remotelogin $hosts[i].lock >& $log &");
}


