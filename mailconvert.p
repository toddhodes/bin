#!/usr/sww/bin/perl

# mailconvert.p  G.Ogle 8/26/99
#
# convert one mh directory of files to a folder in /home/cs/ginger/nsmail/
#    (you will need to restart Netscape to see the new Local Mail folder)


if (@ARGV != 2) {
    print "Usage: mailconvert.p ~ginger/Mail/mh_dirname ns_foldername\n"; 
    exit;
}
$mhdir = $ARGV[0];
$nsmailfolder = $ARGV[1];

### change this to the location of your own nsmail
$nsm = "/home/cs/ginger/nsmail/$nsmailfolder";

`/bin/rm -f $nsm`;
chdir $mhdir;
opendir(DIR, $mhdir) || die "can't opendir $mhdir: $!";
open(NSM, ">>$nsm") || die "Cannot open $nsm: $!";

@filenames = grep(/\d+/,readdir(DIR));
foreach $f (@filenames) {
    if ( -d $f) {
	next;  # skip directories
    }  
    open(F,$f) || die "Cannot open $f: $!";
    while ($line = <F>){
	if ($line =~ /^Date: (.*)$/) {
	    $sofar = "From - $1\n" . $sofar;
	}
	$sofar .= $line;
    }
    close(F);
    print (NSM "$sofar\n\n");
    $sofar = "";
}
close(DIR);
close(NSM);
`chmod 0600 $nsm`;




