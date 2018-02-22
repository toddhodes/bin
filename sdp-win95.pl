eval 'exec perl -S $0 "$@"'
    if $runnning_under_some_shell;

#!/bin/perl

# perl script to extract SDP information and start MBone tools 
# by Rex Xi Xu (rexx@cs.cmu.edu), Nov. 1996
# changes by Christoph Fleck (mmt-ref@tu-dresden.de)

# edit the following list to get your favorite tools
%tools = (
 	"audio", "rat",
#or	"audio", "vat -r",
	"video", "vic",
	"image", "imm",
	"whiteboard", "wbd",
	"text", "nte",
	);

print "-- Starting MBone tools --\n";

$media = "";
while (<>) {
	if (/^s=(.*)/) {
		$title = "\"" . $1 . "\"";
	}
	if (/^m=(.*)/) {
		($media, $port, $proto, $format) = split(' ', $1);
	}
	if (/^c=(.*)/) {
		($nettype, $addrtype, $addr_ttl) = split(' ', $1);
		($addr, $ttl) = split('/', $addr_ttl);
		if ($tools{$media}) {
		if ($media ne "image") {
		$command = join(' ', $tools{$media}, "-t", $ttl, "-C", $title, "${addr}/${port}");
		} else {
		$command = join(' ', $tools{$media}, "-i ${addr} -p ${port}", "\n");
		}
		print $command, "\n";
		system "start $command";
		$media = ""; 	#clear off for the next media
		} else {
		}
	}
}
# print "weiter?";
# $weiter = <STDIN>;
exit 0
