#!/usr/bin/perl
# check-links.pl --- check a URL for dead or moved links.
# Copyright © 1999, 2000 Jamie Zawinski <jwz@jwz.org>
#
# Permission to use, copy, modify, distribute, and sell this software and its
# documentation for any purpose is hereby granted without fee, provided that
# the above copyright notice appear in all copies and that both that
# copyright notice and this permission notice appear in supporting
# documentation.  No representations are made about the suitability of this
# software for any purpose.  It is provided "as is" without express or 
# implied warranty.
# Created: 13-Jun-99.

# usage: check-links *.html > results.html
# It only checks HTTP URLs, and does not recurse.


use POSIX;
use Socket;

my $progname = $0;

my $ok_string = "OK.";

my $head = "<TITLE>link check</TITLE>\n" .
    "<BODY BGCOLOR=\"#FFFFFF\" TEXT=\"#000000\"\n" .
    " LINK=\"#0000EE\" VLINK=\"#551A8B\" ALINK=\"#FF0000\">\n" .
    "\n" .
    "<H1 ALIGN=CENTER>link check</H1>\n" .
    "<CENTER>\n";

my $table_start = "<TABLE BORDER=0 CELLPADDING=2 CELLSPACING=0>\n";
my $table_end = "</TABLE>\n";
my $tail = "</CENTER><HR><P>\n";

my $bgca = "#FFFFFF";
my $bgcb = "#E0E0E0";
my $bgc  = $bgca;

sub check_http_status {
    my ($url) = @_;
    $_ = $url;

    /^http:\/\/([^\/]*)\/*([^ ]*)/;
    my $site = $1;
    my $file = "/".$2;
    
    if (!$site) {
	die "$progname: non-HTTP URL: " . $_ . "\n";
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
        return "Socket failed.";
    }
    if (!connect(S,$there)) {
        return "Connection failed.";
    }
    select(S);$|=1;
    select(STDOUT);$|=1;

    # have to use GET, not HEAD, because some servers are stupid.
    print S "GET $file HTTP/1.0\r\n";
    print S "Host: $hostname\r\n";
    print S "User-Agent: wwwgrab/0.0\r\n";
    print S "\r\n";

    my $status = <S>;

    $status =~ s/[\r\n ]+$//;
    $_ = $status;

    my $location;
    while (<S>) {
        if (m@^$@) {
            last;
        } elsif (m@Location: (.*)@i) {
            $location = $1;
            $location =~ s/[\r\n ]+$//;
        }
    }

    close(S);

    if ($location && $location =~ m@^/@) {
        my $hp = $hostname;
        if ($port && $port ne "80") { $hp .= ":$port"; }
        $location = "http://$hp$location";
    }

    $_ = $status;
    if (m@^HTTP/[0-9.]+ ([0-9]+)( |$)@) {
        my $code = $1;
        if ($code == 200) {
            return $ok_string;
        } elsif ($code == 301 && $location) {
            return "Moved <A HREF=\"$location\"><B>here</B></A>.";
        } elsif ($code == 302 && $location) {
            return "Moved <A HREF=\"$location\"><B><I>here</B></B></A> " .
                "(temporarily).";
        } elsif ($code == 403 || $code == 404) {
            return "Dead.";
        } elsif ($code == 500) {
            return "Server error.";
        } else {
            return "Unknown code \"$code\" in \"$status\".";
        }
    } else {
        return "Unknown status \"$status\".";
    }

    sub getaddress {
	my($host) = @_;
	my(@ary);
	@ary = gethostbyname($host);
	return(unpack("C4",$ary[4]));
    }
}


my $tick = 0;
my $tick2 = 0;
sub check_url {
    my ($url, $title) = @_;

    $_ = $url;

    print "<TR><TD ALIGN=RIGHT VALIGN=TOP BGCOLOR=\"$bgc\">";
    print "<A HREF=\"$url\">$title</A>: ";
    print "</TD><TD ALIGN=LEFT VALIGN=TOP BGCOLOR=\"$bgc\">";

    print STDERR "  $title... ";
    if (m@^http://@) {
        my $status = check_http_status($url);
        if ($status ne $ok_string) {
            print "<B>$status</B>";
        } else {
            print $status;
        }

        if ($status =~ m/unknown/i) {
            print STDERR $status;
        }

    } elsif (m@^mailto:@) {
        print $ok_string;

    } elsif (m@^file:(.*)@) {
        if (-r $1) {
            print $ok_string;
        } else {
            print "<B>File does not exist</B>";
        }
    } else {
        m/^([a-zA-Z]+)/;
        print "Skipping $1 URL.";
    }

    print STDERR "\n";
    print "</TD></TR>\n";

    if (++$tick == 3) {
        $tick = 0;
        if ($bgc eq $bgca) { $bgc = $bgcb; }
        else { $bgc = $bgca; }

        if (++$tick2 == 30) {
            $tick2 = 0;
            print $table_end;
            print $table_start;
        }
    }
}

my $count = 0;
sub read_file {
    my ($file) = @_;
    my $body = "";
    my $base = "file:$file";

    $base =~ s@[^/]*$@@;

    if (open (IN, "<$file")) {
        while (<IN>) {
            $body .= $_;
        }
        close (IN);

        # nuke comments
        $_ = $body;
        while (s@<!--.*?-->@ @) { }
        $body = $_;

        # compact all whitespace
        $body =~ s/[ \t\n]+/ /go;

        # put a newline before each <A> and after each </A>
        $body =~ s@(<A )@\n$1@goi;
        $body =~ s@(</A>)@$1\n@goi;

        $body .= "\n";

        foreach (split(/\n/, $body)) {
            if (m@<A HREF=\"([^\"]+)\"[^>]*>(.*?)</A>@i) {
                my $url = $1;
                my $title = $2;

                $_ = $url;
                if (! m@[a-zA-Z]+:@) {
                    $url = "$base$url";
                    while ($url =~ s@[^/]+/[.][.]/@@g) { }
                    while ($url =~ s@/[.]/@/@g) { }
                }

                $url  =~ s/#.*$//;
                $url   =~ s/[\r\n ]+$//g;
                $url   =~ s/^[\r\n ]+//g;
                $title =~ s/[\r\n ]+$//g;
                $title =~ s/^[\r\n ]+//g;
                $title =~ s/[&][lg]t;//g;
                $title =~ s/<IMG[^>]*>/[ image ]/;
                $title =~ s/<[^>]+>//g;

                check_url($url, $title);
                $count++;
            } elsif (m@http://@) {
                print STDERR "$progname: missed: $_\n";
            }
        }
    }
}

sub main {

    my @files = @_;
    if (@files == 0) {
        @files = ( $ENV{HOME} . "/.netscape/bookmarks.html" );
    }

    print $head;

    foreach (@files) {
        my $file = $_;
        print STDERR "\nChecking $file...\n";
        if (! m@^/@) {
            $file = getcwd . "/" . $file;
        }
        print "<P><HR><P><A HREF=\"file:$file\"><B>$file</B></A><P>\n";
        print $table_start;
        read_file($file);
        print $table_end;
    }
    print $tail;
}
main @ARGV;
exit (0);
