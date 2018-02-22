#!/usr/bin/perl

# worth.pl -- find out the value of your stock, and figure out how much
#             longer you have to wait until you're fully vested.
#             By Jamie Zawinski <jwz@netscape.com> 20-Sep-96.
#             (Still workin' for da man.)

# limitations:
#  only handles stock from one company;
#  assumes all shares vest at the same rate;
#  assumes vesting rate is linear;
#  assumes shares vest daily (probably they vest monthly, or even quarterly);
#  assumes purchase price is negligible.

#### Fill in the numbers here with the date at which your stock began
#### vesting, and ends vesting.  As for mktime, months and mdays start 
#### numbering at 0, not 1; and years is the number of years since 1900,
#### e.g., "1998" would be 98, and "2003" would be 103.

####
#### Note that sometimes when they say "4 years" they really mean "50 months."
####
#                    sec, min, hour, mday, mon, year, wday, yday, isdst
$vest_start = mktime(  0,   0,    0,   ##, ##,   ###,    0,    0,     0);
$vest_end   = mktime(  0,   0,    0,   ##, ##,   ###,    0,    0,     0);

#### How many total shares were you issued?  (This assumes that all of your
#### shares vest on the same schedule.)
####
$total_shares = ##;

#### Of the total number of share you were issued, how many have you already
#### sold?  (Be sure to always count in current, post-split units.)
####
$shares_sold = ##;

#### What company was it that you worked for again?
####
$ticker = "####";


#### You shouldn't need to change anything else.

############################################################################
############################################################################

#$quote_url = "http://www.dbc.com/cgi-bin/htx.exe/squote?ticker=" . 
#    $ticker . "&format=decimals";
#$quote_url = "http://cbs.marketwatch.com/data/squote.htx" .
#             "?source=htx/http2_mw&ticker=" . $ticker . 
#             "&tables=TABLE&format=decimals";

# thanks to dzm@qwe.com for re-finding a working stock URL (1-mar-2000).
$quote_url ="http://quotes.nasdaq-amex.com/Quote.dll?" .
              "page=multi&mode=Stock&symbol=" . $ticker;

use POSIX;

$today = time();

$portion_done = ($today - $vest_start) / ($vest_end - $vest_start);

$shares_vested   = $total_shares * $portion_done;
$shares_unvested = $total_shares - $shares_vested;

$shares_vested_and_unsold = $shares_vested - $shares_sold;

$shares_vested = int($shares_vested);
$shares_unvested = int($shares_unvested);


use Socket;
sub http_grab {

    # mostly snarfed from wwwgrab.pl

    local ($_) = @_;

    /^http:\/\/([^\/]*)\/*([^ ]*)/;
    my $site = $1;
    my $file = "/".$2;
    
    if (!$site) {
	die "$0: non-HTTP URL: " . $_ . "\n";
    }

    $_ = $site;
    /^([^:]*):*([^ ]*)/;
    $site = $1;
    my $port = $2;
    $port = 80 unless $port;

    my $hostname = $site;

    # Open a socket and get the data
    my ($sockaddr,$there,$response,$tries) = ("Snc4x8");
    my $there = pack($sockaddr,2,$port, &getaddress($hostname));
    my ($a, $b, $c, $d) = unpack('C4', $hostaddr);

    my $proto = (getprotobyname ('tcp'))[2];

    if (!socket(S,AF_INET,SOCK_STREAM,$proto)) {
	die "$0:  Fatal Error.  $!\n"; }
    if (!connect(S,$there)) { die "$0:  Fatal Error.  $!\n"; }
    select(S);$|=1;
    select(STDOUT);$|=1;
    print S "GET $file HTTP/1.0\r\n";
#    print S "User-Agent: wwwgrab/0.0\r\n";
    print S "\r\n";
    while(<S>) {
	if (m@Last|[0-9]\.@) {  # oh GAG!  pipe buffer fills up!
	    print $_;
	}
    }
    close(S);

    sub getaddress {
	my($host) = @_;
	my(@ary);
	@ary = gethostbyname($host);
	return(unpack("C4",$ary[4]));
    }
}


sub parse_url {
    my ($url) = @_;

    $per_share_value = 0;

    pipe(PIPEIN, PIPEOUT) || die "Can't make pipe stdout";

    open(SAVEOUT, ">&STDOUT");
    open(STDOUT, ">&PIPEOUT") || die "Can't redirect stdout";
    select(STDOUT); $| = 1;	  # make unbuffered

    http_grab $url;

    close(STDOUT);
    open(STDOUT, ">&SAVEOUT");
    close(PIPEOUT);

    while (<PIPEIN>) {
	if ( m@Last Sale@ ) {
	    # read the next line
	    $_ = <PIPEIN>;
	    ( $per_share_value ) = m@[.]*([0-9.]+)<@;
	}
    }
    if ($per_share_value == 0 || $per_share_value eq "" ) {
	die("unable to find per-share price for \"$ticker\".\n");
    }
    close(PIPEIN);
}

sub commify {
    local ($_) = shift;

    # round it off to cents...
#    $_ = int($_ * 100) / 100;

    # nah.
    $_ = int($_);

    1 while s/^(-?\d+)(\d{3})/$1,$2/;
    return $_;
}


sub print_secs {
    my ( $secs_to_go ) = @_;

    my $days_per_year = 365;
    my $days_per_month = ($days_per_year / 12);

    my $min_to_go    = int($secs_to_go / 60);
    my $hours_to_go  = int($min_to_go / 60);
    my $days_to_go   = int($hours_to_go / 24);

    my $years_to_go  = int($days_to_go / $days_per_year);
    my $months_to_go = int($days_to_go / $days_per_month);

    $months_to_go -= ($years_to_go * 12);
    $days_to_go   -= ($years_to_go * $days_per_year);
    if ($months_to_go < 0) { $months_to_go = 0; }

    $days_to_go -= int($months_to_go * $days_per_month);
    if ($days_to_go < 0) { $days_to_go = 0; }

    # kludge to avoid "1 month 30 days", which, while correct, sucks.
    if ($days_to_go > 29) {
	$days_to_go -= 30;
	$months_to_go += 1;
	if ($months_to_go >= 12) {
	    $months_to_go -= 12;
	    $years_to_go += 1;
	}
    }

#    $days_to_go   = int($days_to_go)   % $days_per_month;
#    $months_to_go = int($months_to_go) % 12;
#    $years_to_go  = int($years_to_go);

    if ( $years_to_go > 0 ) { 
	printf " %d year", $years_to_go;
	if ( $years_to_go != 1 ) { print "s"; };
    }

    if ( $months_to_go > 0 ) { 
	printf " %d month", $months_to_go;
	if ( $months_to_go != 1 ) { print "s"; };
    }

    if ( $days_to_go > 0 ) { 
	printf " %d day", $days_to_go;
	if ( $days_to_go != 1 ) { print "s"; };
    }
}

parse_url $quote_url;

printf "Today's " . $ticker . " price is \$%.2f; ", $per_share_value;
print "your total unsold shares are worth \$";
print commify (($total_shares - $shares_sold) * $per_share_value), ".\n";

if ($portion_done >= 1.0) {
    printf "You are 100%% vested.  Why are you still here?\n\n";
    exit(0);
}

printf "You are %.1f%% vested, for a total of ", ($portion_done * 100);
print commify ($shares_vested_and_unsold), " vested unsold shares (\$";
print commify ($shares_vested_and_unsold * $per_share_value), ").\n";
printf "But if you quit today, you will walk away from \$";
print commify ($shares_unvested * $per_share_value), ".\n";

print "Hang in there, little trooper!  Only";
print_secs ($vest_end - $today);
print " to go!\n";

my $done_aniv = 0;
sub aniv {
    if ($done_aniv) { return; }
    my ($s, $tf) = @_;
    my $years = ($vest_end - $vest_start) / (60*60*24*365);
    my $f = ($years + $tf) / $years;
    my $y = $vest_start + (($vest_end - $vest_start) * $f);
    if ($y < $today) { return; }
    print "Your $s anniversary is ";
    $_ = ctime($y);
    s/^(...) (...)  ?([0-9][0-9]?) .*[0-9][0-9]([0-9][0-9]).*\n/$1, $3-$2-$4/;
    print "$_.\n";
    $done_aniv = 1;
}

print "\n";
aniv("minus-four-year",  -4);
aniv("minus-three-year", -3);
aniv("minus-two-year",   -2);
aniv("minus-one-year",   -1);
aniv("minus-six-month",  -0.5);
aniv("minus-three-month",-0.25);
aniv("minus-one-month",  -0.083);

exit 0;
