#!/usr/local/bin/perl5

# Uses glimpse to search my mail.
# By Jamie Zawinski <jwz@netscape.com>, 18-Jun-96.
#
# If invoked with argv[0] which ends in ".cgi", looks at the $QUERY_STRING
#  environment variable to decide what to do.  Otherwise, passes command
#  line arguments to glimpse and returns output similar to grep (but with
#  mailbox URLs instead of file names and line numbers.)
#
# Todo:
#
#  = Figure out a way to make it search the entire message, instead of
#    being limited to a line at a time (make it an option.)

$glimpse  = "/usr/local/bin/glimpse";
$extra_glimpse_args = "-H /u/jwz/nsmail/.glimpse";

############################################################################

$ENV{'PATH'} = '/bin:/usr/bin';
$ENV{'SHELL'} = '/bin/sh'	if defined $ENV{'SHELL'};
$ENV{'IFS'} = ''		if defined $ENV{'IFS'};

sub url_quote {
    die "expected 1 arg to url_quote" unless @_ == 1;
    local $_ = shift;
    s|([^-a-zA-Z0-9.\@/_\r\n])|sprintf("%%%02X", ord($1))|ge;
    return $_;
}

sub url_unquote {
    die "expected 1 arg to url_quote" unless @_ == 1;
    local $_ = shift;
    s/[+]/ /g;
    s/%([a-z0-9]{2})/chr(hex($1))/ige;
    return $_;
}

sub html_quote {
    die "expected 1 arg to url_quote" unless @_ == 1;
    local $_ = shift;
    s/&/&amp;/g;
    s/</&lt;/g;
    s/>/&gt;/g;
    return $_;
}

sub sh_quote {
    die "expected 1 arg to sh_quote" unless @_ == 1;
    local $_ = shift;
    s/([^-_.a-zA-Z0-9])/\\\1/g;
    return $_;
}


sub run_glimpse {
    die "expected 1 arg to run_glimpse" unless (@_ == 1 || @_ == 2);
    local ($_, $emit_html_p) = @_;

    local $command = $glimpse . " -b -y " . $extra_glimpse_args . " " . $_;

    if ($emit_html_p) {
	local $c2;
	($c2 = $command) =~ s|^/?([^/ ]+/)*||;
	print "<P ALIGN=CENTER><FONT SIZE=\"-1\"><TT>", html_quote($c2);
	print "</P></FONT></TT></P><P><HR><P>\n";
    }

    foreach $line ( `$command` ) {
	$line = hack_line($line);
	if ($line ne "") {
	    if ($emit_html_p) { $line = quote_line($line); }
	    print $line, "\n";
	}
    }
}

# turns the output from glimpse into a mailbox: URL followed by the match.
sub hack_line {
    die "expected 1 arg to hack_line" unless @_ == 1;
    local $_ = shift;
    local ($file, $byte, $match) = m/^([^:]+): *([^=]+)= *(.*)$/;

    $_ = find_mid("-b", $byte, $file);
    local ($msg_num, $msg_id) = m/^([0-9]+)[ \t\n]*<?([^>]*)>?$/;

    local $result = "mailbox:" . url_quote($file);
    if ($msg_id ne "" && $msg_id ne 0) {
	$result = $result . "?id=" . url_quote($msg_id);
    }

    if ($msg_num ne "" && $msg_num ne 0) {
	$result = $result . (($msg_id eq "" || $msg_id eq 0) ? "?" : "&") .
	    "number=" . url_quote($msg_num);
    }
    if (($msg_id  eq "" || $msg_id  eq 0) &&
	($msg_num eq "" || $msg_num eq 0)) {
	return "";
    }

    return $result . "\t" . $match;
}

# turns the output from hack_line() into presentable HTML.
sub quote_line {
    die "expected 1 arg to quote_line" unless @_ == 1;
    local $_ = shift;
    local ($url, $match) = m/^([^ \t]+)[ \t]+(.+)$/;
    $_ = $url;
    local ($file)   = m/^[^:]+:([^?]+)/;
    local ($number) = m/number=([0-9]*)/;
    ($file) =~ s!.*?([^/]+)$!\1!;
#    return "<A HREF=\"" . $url . "\">" .
#	html_quote($file . "#" . $number) . "</A>" .
#	"<TT>&nbsp;&nbsp;&nbsp;</TT>" .
#	html_quote($match) . "<BR>";

    local $tag = $file . "#" . $number;
    local $result =
	"<TABLE BORDER=0 CELLPADDING=0 CELLSPACING=0 WIDTH=\"100%\">" .
	"<TR><TD WIDTH=\"15%\" VALIGN=TOP>";

    if ($tag eq $prev_quoted_tag) {
	#$result = $result . "&nbsp;";
    } else {
	$result = $result .
	    "<A HREF=\"" . $url . "\">" . html_quote($tag) . "</A>";
	$prev_quoted_tag = $tag;
    }
    $result = $result . "</TD><TD WIDTH=\"85%\">" .
	html_quote($match) . "</TD></TR></TABLE>";
    return $result;
}

sub run_glimpse_cgi {
    die "expected 0 args to run_glimpse_cgi" unless @_ == 0;
    local $_ = shift;
    local $search="";
    local $files="";
    local $errors="";
    local $case_p=0;
    local $word_p=0;

    print "Content-Type: text/html\n\n";

    # Since this junk has to run as setuid in order to read my mail indexes,
    # don't allow the CGI script to run unless it's being accessed directly
    # from my machine.  (This assumes that logins on my machine are secured,
    # but that HTTP connections to it are not.)
    #
    if ( $ENV{"REMOTE_ADDR"} ne "127.0.0.1" &&
	 $ENV{"REMOTE_ADDR"} ne "209.157.133.130" &&
	 $ENV{"REMOTE_ADDR"} ne "209.157.133.131" &&
	 $ENV{"REMOTE_ADDR"} ne "209.157.133.132" ) {
	print "<TITLE>piss off</TITLE>",
		"<BODY BGCOLOR=BLACK>",
		"<TABLE BORDER=0 WIDTH=\"100%\" HEIGHT=\"100%\">",
		"<TR><TD ALIGN=CENTER VALIGN=CENTER>",
		"<H1><FONT COLOR=RED>Who invited you?</BR>Go away.</FONT>",
		"</TD></TR></TABLE></CENTER>";
	exit(-1);
    }

    $_ = $ENV{"QUERY_STRING"};

    local $body_tag = "<BODY BGCOLOR=\"#F5F5F5\" TEXT=\"#000000\" " .
		      "LINK=\"#0000EE\" VLINK=\"#551A8B\" ALINK=\"#FF0000\">";

    if ($_ eq "") {
	print "<TITLE>Mail Search</TITLE>", $body_tag;
	print "<H1 ALIGN=CENTER>Mail Search</H1>";
	write_control_panel_html($search, $files, $errors, $case_p, $word_p);
	
    } else {
	foreach (split(/[?&;]/) ) {
	    local($key, $value) = m/^([^=]+)=?(.*)$/;
	    if    ($key eq "search") { $search = url_unquote($value); }
	    elsif ($key eq "files")  { $files = url_unquote($value); }
	    elsif ($key eq "errors") { $errors = url_unquote($value); }
	    elsif ($key eq "case")   {
		$case_p = ($value eq "true" || $value eq "TRUE"); }
	    elsif ($key eq "words")  {
		$word_p = ($value eq "true" || $value eq "TRUE"); }
	    else  { die "unknown key $key"; }
	}

	local $args = "";
	if ($files)   { $args = $args . " -F " . sh_quote($files); }
	if ($errors)  { $args = $args . " -"   . sh_quote($errors); }
	if (!$case_p) { $args = $args . " -i"; }
	if ($word_p)  { $args = $args . " -w"; }
	if ($search)  { $args = $args . " " . sh_quote($search); }

	print "<TITLE>Mail Search: ", html_quote($search), "</TITLE>";
	print $body_tag;
	print "<H1 ALIGN=CENTER>Mail Search: ", html_quote($search), "</H1>";

	run_glimpse($args, 1);

	print "<P>";
	write_control_panel_html($search, $files, $errors, $case_p, $word_p);
    }
}

sub write_control_panel_html {
    die "expected 5 args to write_control_panel_html" unless @_ == 5;
    ($search, $files, $errors, $case_p, $word_p) = @_;

    if ($errors eq "") { $errors = "0"; }

    print 
 "  <FORM METHOD=GET>
   <CENTER><TABLE BORDER><TR><TD>
   <TABLE BORDER=0 CELLSPACING=0 CELLPADDING=2>
    <TR>
     <TH ALIGN=RIGHT>Search for:</TH>
     <TD COLSPAN=6>
      <INPUT TYPE=TEXT SIZE=50 NAME=search VALUE=\"",
	  html_quote($search),
 "\"> <B><INPUT TYPE=SUBMIT VALUE=\" Search \"></B>
     </TD>
    </TR>
    <TR>
     <TH ALIGN=RIGHT>In files:</TH>
     <TD COLSPAN=6>
      <INPUT TYPE=TEXT SIZE=60 NAME=files VALUE=\"", html_quote($files),
 "\">
     </TD>
    </TR>
    <TR>
     <TH ALIGN=RIGHT>Closeness:</TH>
     <TD>
      <INPUT TYPE=TEXT SIZE=5 NAME=errors VALUE=\"", html_quote($errors),
 "\">
    </TD>

     <TH ALIGN=RIGHT>Case Sensitive:</TH>
     <TD>
      <INPUT TYPE=CHECKBOX NAME=case VALUE=true", ($case_p ? " CHECKED" : ""), 
 ">
     </TD>
  
     <TH ALIGN=RIGHT>Word Search:</TH>
     <TD>
      <INPUT TYPE=CHECKBOX NAME=words VALUE=true", ($word_p ? " CHECKED" : ""),
 ">
     </TD>
  
    </TR>

    <TR>
     <TD></TD>
     <TD COLSPAN=4 ALIGN=CENTER VALIGN=TOP>
       <TABLE BORDER=0 CELLPADDING=0 CELLSPACING=0><TR><TD>
        <HR>
	<B><TT>;</TT></B> between words indicates <B>and</B><BR>
	<B><TT>,</TT></B> between words indicates <B>or</B><BR>
	<B><TT>#</TT></B> matches 0 or more characters<BR>
	<B><TT>&lt;</TT></B><I>text</I><B><TT>&gt;</TT></B> means
	  <I>text</I> must match exactly.<BR>
	  &nbsp;&nbsp;and if none of that matches, the text is 
	  interpreted as a regexp:<BR>
	&nbsp;&nbsp;<B><TT>|</TT></B>, <B><TT>*</TT></B>, and
	 <B><TT>()</TT></B> work, but <B><TT>+</TT></B> does not, and
	 the regexp is limited to<BR>
	 &nbsp;&nbsp; around 30 characters.
        <P>
      </TD></TR></TABLE>
     </TD>
    </TR>
   </TABLE>
   </TD></TR></TABLE></CENTER>
  </FORM>\n";
}


sub find_mid {
    die "expected 2-3 args to write_control_panel_html"
	unless (@_ == 2 || @_ == 3);
    local $bytes_p = 0;
    local $index;
    local $file;

    $index = shift;

    $_ = $index;
    if ( m/^-b$/ ) {
	$bytes_p = 1;
	$index = shift;
    } elsif ( m/^-l$/ ) {
	$bytes_p = 0;
	$index = shift;
    } elsif ( m/^-/ ) {
	die "unknown switch $_ in find_mid.\n";
    }
    $file = shift;
    if (shift) { die("expected 2-3 args to write_control_panel_html"); }

    # printf STDERR "looking for %s in %s\n", $index, $file;

    sub find_mid_reset {
	$find_mid_name = 0;
	$find_mid_byte = 0;
	$find_mid_line = 0;
	$find_mid_id = 0;
	$find_mid_blank_p = 0;
	$find_mid_header_p = 1;
	$find_mid_moz = 0;
	$find_mid_msgnum = -1;

	# Set this to true to treat the separator as "\n\nFrom ".  If
	# undefined, "\nFrom " is used (Mozilla bug compatibility.)
	$find_mid_strict_sep = 0;
    }

    if (!$find_mid_initted) {
	find_mid_reset();
	$find_mid_initted = 1;
    }


    if ($file ne $find_mid_name ||
	($bytes_p
	 ? ($find_mid_byte > $index)
	 : ($find_mid_line > $index))) {
	if ($find_mid_name) {
	    # printf STDERR "closing %s\n", $find_mid_name;

	    close MIDS;
	    find_mid_reset();
	}
	open(MIDS, $file);
	$find_mid_name = $file;
    }

    local $line;
  EOF: while ($line = <MIDS>) {

      $find_mid_line++;
      $find_mid_byte += length($line);

      $_ = $line;
      if ($line eq "\n") {
	  # printf STDERR "line %d is blank\n", $find_mid_line;
	  $find_mid_blank_p = 1;
	  $find_mid_header_p = 0;
	  next;
      }

      $_ = $line;
      if ((!$find_mid_strict_sep || $find_mid_blank_p) &&
	  m/^From / ) {
	  $find_mid_id = 0;
	  $find_mid_moz = 0;
	  $find_mid_header_p = 1;
	  $find_mid_msgnum++;

	  # printf STDERR "line %d is a separator\n", $find_mid_line;

      } elsif ($find_mid_header_p && 
	       m/^Message-ID:[ \t]*(<[^>]+>)[ \t]*$/i) {
	  ($find_mid_id) = m/^Message-ID:[ \t]*(<[^>]+>)[ \t]*$/i;
	  # printf STDERR "line %d has message ID %s for msg #%d\n",
	  #    $find_mid_line, $find_mid_id, $find_mid_msgnum;

      } elsif ($find_mid_header_p && 
	       m/^X-Mozilla-Status:[ \t]*(.+)$/i) {
	  ($find_mid_moz) = m/^X-Mozilla-Status:[ \t]*(.+)$/i;
	  # printf STDERR "line %d has status %s for msg #%d\n",
	  #     $find_mid_line, $find_mid_moz, $find_mid_msgnum;
      }

      $find_mid_blank_p = 0;

      if ($bytes_p
	  ? ($find_mid_byte >= $index)
	  : ($find_mid_line >= $index)) {

	  if ($find_mid_moz && (hex($find_mid_moz) & 8)) {
	      # printf STDERR "msg #%d is deleted " .
	      #   "(%s => 0x%04X which has 0x0008 set)\n",
	      #       $find_mid_msgnum, $find_mid_moz, hex($find_mid_moz);

	      return "";
	  }

	  return sprintf("%d %s", $find_mid_msgnum, $find_mid_id);
      }
  }
  return "";
}



sub main {

    # unbuffer all streams.
    select(STDIN);  $| = 1;
    select(STDERR); $| = 1;
    select(STDOUT); $| = 1;

    $_ = $0;
    if ( m/\.cgi$/ ) {
	run_glimpse_cgi();
    } else {
	local $args = "";
	for (@ARGV) {
	    if ($args ne "") { $args .= " " };
	    $args .= sh_quote($_);
	}
	if ($args eq "") {
	    print STDERR "usage: $0 [ glimpse-args ... ]\n";
	    #system $glimpse;
	    exit(1);
	}
	run_glimpse($args);
    }
}

main();
exit(0);
