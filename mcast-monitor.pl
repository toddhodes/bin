#!/usr/local/bin/perl

#!/usr/bin/perl
## mcast-monitor.pl  --  monitors multicast traffic.

## (C) 1995 by Martin Horneffer <Horneffer@rrz.uni-koeln.de>
##             Rechenzentrum der Universität zu Köln
##
## Permission granted to redistribute 
## as long as copyright is left intact.


## Known Bugs:

## - assumes vt100 and fixed number of lines

## Future:

## - use termcap
## - detect (configurable) overload-conditions and send SNMP-traps


## Commands (on STDIN when prg is running):

##  " " or "\n": update display
##  "q"        : update display and quit
##  "Q"        : immediate quit


## Defaults:

$update = 60;
$lines = 24;

## Monitor local by default:
#$command_local = "tcpdump -lv ip multicast";
#$command_local = "tcpdump -nlv ip";
$command_local = "tcpdump -lv ip";
$command_tunnel = "tcpdump -lv ip proto 4";
$command = $command_local;


## Program:
## (You should not normally have to change anything below!)

# $Log: mcast-monitor.pl,v $
# Revision 1.4  1995/10/25  10:37:34  maho
# accecpt tcpdump output "snap ip".
# summarize lines that won't fit on display.
#
# Revision 1.3  1995/10/19  16:15:30  maho
# use select() and read commands from stdin:
#   "Q" to quit and " " to update display.
#
# Revision 1.2  1995/10/18  15:34:00  maho
# Use function time() instead of tcpdump output in order to fix midnight-bug.
#
# Revision 1.1  1995/10/17  16:09:12  maho
# Initial revision
#

while ( $arg = shift ) {
    if ( $arg eq "-u" ) {
	$update = shift;
    } elsif ( $arg eq "-l" ) {
	$lines = shift;
    } elsif ( $arg eq "-c" ) {
	$command = shift;
    } elsif ( $arg eq "-t" ) {
	$arg = shift;
	if ( $arg eq "local" ) {
	    $command = $command_local;
	} elsif ( $arg eq "tunnel" ) {
	    $command = $command_tunnel;
	} else {
	    print STDERR "ignored: -t $arg\n";
	};
    } else {
	print STDERR "unknown option: $arg\n"
	     ."usage: $0 [-l lines] [-u seconds] [-t local|tunnel] [-c tcpdump-command]\n\n";
	exit 1;
    };
};


open(DUMP, "$command |") || die "cannot start tcpdump.";

$rin = '';
vec($rin, fileno(STDIN), 1) = 1;
vec($rin, fileno(DUMP), 1) = 1;
system "stty -icanon min 1 time 0";

while ( &collect() ) {};

# close(DUMP); # does no good

exit 0;


sub collect {
    local ( $starttime, $now ) = ( time(), time() );
    local ( $packets, $bytes, $quit ) = ( 0, 0, 0 );
    local ( %mcastpackets, %mcastbytes, %tunnelpackets, %tunnelbytes );
    local ( @tunnel, @mcast );

  loop:
    while ( !$quit && ($now-$starttime < $update) ) {
	
	select($rout=$rin, undef, undef, $update-$now+$starttime);
	$now = time();
	
	if ( vec($rout, fileno(DUMP), 1)==1 ) {
	    $_ = $line = <DUMP>;
	    if ( /^(\d\d):(\d\d):(\d\d\.\d*) snap ip\s+(.*)$/
		 || /^(\d\d):(\d\d):(\d\d\.\d*)\s+(.*)$/ ) {
		( $hour, $min, $sec, $_ ) = ( $1, $2, $3, $4 );
		if ( /^([\w\-\.]+) > ([\w\-\.]+):.*ip-proto-4\s+(\d+)/ ) {
		    # tcpdump-2.2
		    $packets ++;
		    $bytes += $3;
		    $i = sprintf "%32.32s > %-30.30s", $1, $2;
		    $tunnelpackets{$i} ++;
		    $tunnelbytes{$i} += $3;
		} elsif ( /^([\w\-\.]+) > ([\w\-\.]+):\s*([\w\-\.]+)\.\d+ > ([\w\-\.]+)\.\d+:\s+([\w\-\.]+)\s+(\d+)/
			 || /^([\w\-\.]+) > ([\w\-\.]+):\s*([\w\-\.]+) > ([\w\-\.]+):\s+([\w\-\.]+)\s+(\d+)/ ) {
		    # tcpdump -v, tunneled
		    $packets ++;
		    $bytes += $6;
		    $i = sprintf "%32.32s > %-30.30s", $1, $2;
		    $tunnelpackets{$i} ++;
		    $tunnelbytes{$i} += $6;
		    $i = sprintf "%-5s %32.32s > %-24.24s", $5, $3, $4;
		    $mcastpackets{$i} ++;
		    $mcastbytes{$i} += $6;
		} elsif ( /^([\w\-\.]+) > ([\w\-\.]+):\s*([\w\-\.]+) > ([\w\-\.]+):.*\[len=(\d+)\]\s(.....)/ ) {
		    # tcpdump -v, tunneled
		    $packets ++;
		    $bytes += $5;
		    $i = sprintf "%32.32s > %-30.30s", $1, $2;
		    $tunnelpackets{$i} ++;
		    $tunnelbytes{$i} += $5;
		    $i = sprintf "%-5s %32.32s > %-24.24s", $6, $3, $4;
		    $mcastpackets{$i} ++;
		    $mcastbytes{$i} += $5;
		} elsif ( /^([\w\-\.]+)\.\d+ > ([\w\-\.]+)\.\d+:\s+([\w\-\.]+)\s+(\d+)/
			 || /^([\w\-\.]+) > ([\w\-\.]+):\s+([\w\-\.]+)\s+(\d+)/ ) {
		    # standard tcpdump
		    $bytes += $4;
		    $packets ++;
		    $i = sprintf "%-5s %32.32s > %-24.24s", $3, $1, $2;
		    $mcastbytes{$i} += $4;
		    $mcastpackets{$i} ++;
		} elsif ( /^([\w\-\.]+) > ([\w\-\.]+):.*\[len=(\d+)\]\s(.....)/ ) {
		    # standard tcpdump
		    $bytes += $3;
		    $packets ++;
		    $i = sprintf "%-5s %32.32s > %-24.24s", $4, $1, $2;
		    $mcastbytes{$i} += $3;
		    $mcastpackets{$i} ++;
		} elsif ( /^([\w\-\.]+) > ([\w\-\.]+):\s*([\w\-\.]+) > ([\w\-\.]+):\s+([\w\-\.]+)/ ) {
		    # tcpdump -v, other type, no size
		    $packets ++;
		    $i = sprintf "%32.32s > %-30.30s", $1, $2;
		    $tunnelpackets{$i} ++;
		    $i = sprintf "%-5s %32.32s > %-24.24s", $5, $3, $4;
		    $mcastpackets{$i} ++;
		} elsif ( /^([\w\-\.]+) > ([\w\-\.]+):\s+([\w\-\.]+)/ ) {
		    # standard tcpdump, other type, no size
		    $packets ++;
		    $i = sprintf "%-5s %32.32s > %-24.24s", $3, $1, $2;
		    $mcastpackets{$i} ++;
		} else {
		    print STDERR "unknown: $line\n";
		};
	    } else {
		print STDERR "unknown: $line\n";
	    };
	};

	if ( vec($rout, fileno(STDIN), 1)==1 ) {
	    $c = getc(STDIN);
	    if ( $c eq "q" ) {
		$quit = 1;
		last loop;
	    } elsif ( $c eq "Q" ) {
		exit 0;
	    } elsif ( ($c eq " ") || ($c eq "\n") ) {
		last loop;
	    } else {
		print STDERR "unknown command: $c\n";
	    };
	};
    };

    if ( $now-$starttime > 0 ) {
	$rate = 8/1000/($now-$starttime);
    } else {
	$rate = 8/1000;
    };
    
    foreach $i ( keys(%tunnelpackets) ) {
	push @tunnel, sprintf("\n%4d%9.1f %.66s", $tunnelpackets{$i}, $tunnelbytes{$i} * $rate, $i);
    };
    @tunnel = reverse sort(@tunnel);

    foreach $i ( keys(%mcastpackets) ) {
	push @mcast, sprintf("\n%4d%9.1f %.66s", $mcastpackets{$i}, $mcastbytes{$i} * $rate, $i);
    };
    @mcast = reverse sort(@mcast);

    ( $sec, $min, $hour ) = localtime( $now );
    print "\e[H\e[J";
    printf "%02d:%02d:%02d, last %d secs: %d bytes (%.1f kbps) in %d packets.\n", $hour, $min, $sec, $now-$starttime, $bytes, $bytes * $rate, $packets;

    $rlines = $lines - 1;

    if ( @tunnel ) {
	$rlines -= 2 + @tunnel;
	print "\n\e[4m  pkts  kbps                --- tunnel ---                                      \e[m";
	print @tunnel, "\n";
    };

    if ( @mcast ) {
	$rlines -=2;
	print "\n\e[4m  pkts  kbps proto         --- multicast ---                                    \e[m";
	if ( $rlines >= @mcast ) {
	    print @mcast;
	} else {
	    print splice(@mcast, 0, $rlines-1);
	    ($opackets, $obytes) = (0, 0);
	    $obytes = 0;
	    foreach ( @mcast ) {
		/^\s*(\d+)\s+([\d\.]+)/ ;
		$opackets += $1;
		$obytes += $2;
	    };
	    printf("\n%6d%6.1f --- (%d other connections) ---", 
		   $opackets, $obytes, scalar(@mcast));
	};
    };

    $| = 1;
    print "\e[H\e[1B> ";
    $| = 0;

    return ( !$quit );
};

