#

#!/usr/sww/bin/perl 
#curr usage:: set | grep ^PATH | cut -d"=" -f2 | perl fixMyPath.pl

while(<>) {
	chop ; 
	foreach $i (split(/:/)) {
		print $i; print "\n" ;
	}
}

