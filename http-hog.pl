#!/usr/sww/bin/perl
$top_count = 20;
$usage = "$0: [-top n] [-prevmonth <filename>] <filename>";
while ($ARGV[0] =~ /^-/o) {
    $_ = shift @ARGV;
    if (/^-top$/o) {
	$top_count = shift @ARGV;
    } elsif (/^-prevmonth$/o) {
	$prevmonth = shift @ARGV;
    } elsif (/^-h/io) {
	die($usage);
    } else {
	die($usage);
    }
}
die ($usage) unless $#ARGV == 0;

$name = $ARGV[0];
$name =~ s!.*/!!o;
if ($name =~ /^(\w+)-(\d+)\.html$/o) {
    $month = $1;
    $year = $2;
} elsif ($name =~ /^(\w+)\.html$/o) {
    $month = $1;
    $year = (localtime(time))[5] + 1900;
    warn "Filename isn't month-year, assuming year for file is $year\n";
} else {
    die("make filename month-year.html");
}

@okthings = ( 'projects','prospective','server','world','students',
	     'newspages','labels','images','icons','homepages',
	     'feedback','enjoy','doc','directions','csdiv','csbrochure',
	     'conferences','coe','cgi-bin','TEMP','Students','Servers',
	     'Seminars','Research','People','Network','HTMLicons',
	     'Administration','buttons','public','swwimages');
foreach $okthing (@okthings) {
    $okthings{$okthing} = 1;
}

if (defined $prevmonth) {
    &processfile($prevmonth);
    $count = 0;
    foreach $user (&topbybytes(1000000)) {
	++$count;
	$lmbyterank{$user} = $count;
    }
    $count = 0;
    foreach $user (&topbyaccesses(1000000)) {
	++$count;
	$lmaccessrank{$user} = $count;
    }
    %lmbytes = %bytes;
    %lmaccesses = %accesses;
    undef %bytes;
    undef %accesses;
}

&processfile($ARGV[0]);

print "<TITLE>Top $top_count for $month $year</TITLE>\n";
print "<H1>Top $top_count for $month $year</H1>\n";
print "<PRE>\n";


if (defined $prevmonth) {
    &prevmonthformat;
} else {
    &topformat;
}

if (defined $prevmonth) {
    $foo1 = "Last Month Rank / Bytes";
    $foo2 = "-- -------------------";
} else {
    $foo1 = $foo2 = '';
}
print "
Top $top_count by bytes transferred:
#   User        Bytes Transferred  Total Accesses   $foo1
--  ----------  -----------------  --------------   $foo2
";
$num = 0;
foreach $user (&topbybytes($top_count)) {
#    print "Yo:$user\n";
    ++$num;
    $bytes = &commize($bytes{$user});
    $accesses = &commize($accesses{$user});
    $lastnum = $lmbyterank{$user} || "?";
    $lastval = &commize($lmbytes{$user}) || "?";
    write;
}

if (defined $prevmonth) {
    $foo1 = "Last Month Rank / Accesses";
    $foo2 = "--  ---------------------";
} else {
    $foo1 = $foo2 = '';
}
print "
Top $top_count by number of accesses:
#   User        Bytes Transferred  Total Accesses   $foo1
--  ----------  -----------------  --------------   $foo2
";

$num = 0;
foreach $user (&topbyaccesses($top_count)) {
    ++$num;
    $bytes = &commize($bytes{$user});
    $accesses = &commize($accesses{$user});
    $lastnum = $lmaccessrank{$user} || "?";
    $lastval = &commize($lmaccesses{$user}) || "?";
    write;
}

print "</PRE>\n";
sub topbybytes {
    return &firstn($_[0],sort bybytes (keys %bytes));
}

sub topbyaccesses {
    return &firstn($_[0],sort byaccesses (keys %accesses));
}

sub firstn {
    local($n,@tmp) = @_;

    splice(@tmp,$n,$#tmp) if ($#tmp >= $n);
    return @tmp;
}

sub bybytes { $bytes{$b} <=> $bytes{$a} }
sub byaccesses { $accesses{$b} <=> $accesses{$a} }

sub commize {
    local($_) = $_[0];

    while(/\d{4}/o) {
#	print "In:$_\n";
	s/(\d*)(\d{3})(,|$)/$1,$2$3/o;
#	print "Out:$_\n";
    }
    return $_;
}

sub processfile {
    local($filename) = @_;

    open(INFILE,$filename) || die("Can't open $filename for read:$!\n");
    while(<INFILE>) {
	last if /^<H2>/o && /Total Transfers from each Archive Section/o;
    }
    $_ = <INFILE>;
    die("Bad1:$_\n") unless $_ eq "<PRE>\n";
    $_ = <INFILE>;
    die("Bad2:$_\n") unless /^%Reqs\s%Byte\s+Bytes\sSent\s+Request/o;
    $_ = <INFILE>;
    die("Bad3:$_\n") unless /^----- ----- -----/o;

#print "Yo:$_\n";
    while(<INFILE>) {
	unless (m!/((~)|(%7E)|(%7e))([A-Za-z0-9%\.]+)/!o) {
	    if (m!\| /([^/]+)/!o) {
#	    print "Yo:$1\n";
		next if defined $okthings{$1};
	    }
	    next if / \| All Icons \(server\)/o;
	    next if / \| Code \d\d\d /o;
	    next if m!/[^/]+$!o || m!/\./$!o || m!list_of_contacts/?$!o;
	    last if /^<HR>$/o;
	    chop;
	    print STDERR "***Bad Line:'$_'\n";
	    next;
	}
	$user = $5;
	die("Internal Error: $user;$_\n")
	    unless $user =~ /^[A-Za-z0-9%\.]+$/o;
#    print "$user;$_\n";
	s/^\s+//o;
	s/\s+$//o;
#    print "Yo:$_\n";
	@parts = split(/\s+/o);
	unless ($#parts == 5) 
	{
	    warn("Bad Line:$_\n");
	    next;
	}
#	print "Bene:$_\n";
	$bytes{$user} += $parts[2];
	$accesses{$user} += $parts[3];
    }
}

sub topformat {
eval '
format STDOUT = 
@<  @<<<<<<<<<  @<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<<
$num, $user, $bytes, $accesses
.
'
}

sub prevmonthformat {
eval '
format STDOUT = 
@<  @<<<<<<<<<  @<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<<   @<< @<<<<<<<<<<<<<<<<
$num, $user, $bytes, $accesses, $lastnum, $lastval
.
'
}
