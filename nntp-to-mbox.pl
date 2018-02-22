#!/usr/bin/perl
# Copyright © 1999, 2000 Jamie Zawinski <jwz@jwz.org>
#
# Permission to use, copy, modify, distribute, and sell this software and its
# documentation for any purpose is hereby granted without fee, provided that
# the above copyright notice appear in all copies and that both that
# copyright notice and this permission notice appear in supporting
# documentation.  No representations are made about the suitability of this
# software for any purpose.  It is provided "as is" without express or 
# implied warranty.
#
# Created: 26-Mar-99.

# Usage: nntp-to-mbox.pl hostname group [from-article] [to-article]
#
# Connects to an NNTP server, extracts a series of messages from a newsgroup,
# and writes those to stdout in BSD "mbox" format -- including generation of
# envelope lines and proper quoting of bodies.  If no article range is
# specified, does the whole group.

use POSIX;
use Socket;

sub nntp_command {
    my ($cmd) = @_;
    $cmd =~ s/[\r\n]+$//;	# canonicalize linebreaks.
    print STDERR ">> $cmd\n";
    print NNTP "$cmd\r\n";
}

sub nntp_response {
    my ($no_error) = @_;
    $_ = <NNTP>;
    s/[\r\n]+$//;		# canonicalize linebreaks.
    print STDERR "<< $_\n";
    if ( ! m/^[0-9][0-9][0-9] / ) {
        die("malformed NNTP response: $_");
    }
    if ( ! $no_error && ! m/^2[0-9][0-9] / ) {
        die("NNTP error: $_");
    }
    return $_;
}

sub nntp_open {
    my ($hostname, $port) = @_;
    $port = 119 unless $port;

    # Open a socket and get the data
    my ($sockaddr,$there,$response,$tries) = ("Snc4x8");
    my $there = pack($sockaddr,2,$port, &getaddress($hostname));
    my ($a, $b, $c, $d) = unpack('C4', $hostaddr);

    my $proto = (getprotobyname ('tcp'))[2];

    if (!socket(NNTP,AF_INET,SOCK_STREAM,$proto)) {
	die "$0:  Fatal Error.  $!\n"; }
    if (!connect(NNTP,$there)) { die "$0:  Fatal Error.  $!\n"; }
    select(NNTP);$|=1;
    select(STDOUT);$|=1;

    nntp_response;

    sub getaddress {
	my($host) = @_;
	my(@ary);
	@ary = gethostbyname($host);
	return(unpack("C4",$ary[4]));
    }
}

sub nntp_close {
    nntp_command "QUIT";
    close NNTP;
}


sub nntp_group {
    my ($group) = @_;
    nntp_command "GROUP $group";
    $_ = nntp_response;
    my ($from, $to) = m/^[0-9]+ [0-9]+ ([0-9]+) ([0-9]+) .*/;
    return ($from, $to);
}

sub nntp_article {
    my ($art) = @_;
    nntp_command "ARTICLE $art";
    $_ = nntp_response 1;

    if ( m/^423 / ) {
        print STDERR "Article $art expired or cancelled?\n";
        return;
    }

    if ( ! m/^2[0-9][0-9] / ) {
        die("NNTP error: $_");
    }

    print "From $art -\n";		# tag mbox with article number
    print "X-Mozilla-Status: 0000\n";	# leave room for status updates

    while (<NNTP>) {
        s/[\r\n]+$//;		# canonicalize linebreaks.
        last if m/^\.$/;	# lone dot terminates
        s/^\.//;		# de-dottify.
        s/^(From )/>\1/;	# de-Fromify.
        print "$_\n";
    }
    print "\n";
}

sub main {
    my ($hostname, $group, $from, $to, $loser) = @_;

    if ( !$hostname || !$group || $loser ) {
        printf "usage: $0 hostname group [from-article] [to-article]\n";
        exit 1;
    }

    nntp_open $hostname;
    my ($f, $t) = nntp_group($group);

    if (!$from) {
        print "$group $f-$t\n";
    } else {
        if ( $from < $f ) { $from = $f; }
        if ( !$to || $to > $t ) { $to = $t; }

        while ($from <= $to) {
            nntp_article $from;
            $from++;
        }
    }

    nntp_close;
}

main @ARGV;
exit 0;
