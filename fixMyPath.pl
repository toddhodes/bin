#

#!/usr/sww/bin/perl 
#curr usage:: set | grep ^PATH | cut -d"=" -f2 | perl fixMyPath.pl

$arr{"."} = 1 ;
$arr{"/"} = 1 ;

while(<>) {
	chop ; 
	#print "/" ;
	foreach $i (split(/:/)) {
		#print "$i\n";
		if (($arr{$i} == 0) && (-d $i)) {
			#print $i; print "\n" ;
			print $i ; print ":" ;
			$arr{$i} = 1 ;
		}
	}
	print ".\n" ;
}

