#! /usr/bin/perl
#
#           De-moron-ise Text from Microsoft Applications
# 
#                   by John Walker -- January 1998
#                      http://www.fourmilab.ch/
#
#               This program is in the public domain.
#

    $lineWrap = 72;                   # Wrap lines at this column
    $lineBreak1 = '[<]';              # Line break first pass candidates
    $lineBreak2 = '[>]';              # Line break second pass candidates

    #   Process command line options

    for ($i = 0; $i <= $#ARGV; $i++) {
        if ($ARGV[$i] =~ m/^-/) {
            $o = $ARGV[$i];
            splice(@ARGV, $i, 1);
            $i--;
            if (length($o) == 1) {
                last;
            }
            $opt = substr($o, 1, 1);
            $arg = substr($o, 2);

            #   -u                  -- Print how-to-call information

            if ($opt eq 'u' || $opt eq '?') {
                print("Usage: demoroniser [ options ] infile outfile\n");
                print("       Options:\n");
                print("             -u              Print this message.\n");
                print("             -wcols          Wrap lines at cols columns, 0 = no wrap.\n");
                exit(0);

            #   -wcols              -- Wrap lines at cols columns, 0 = no wrap

            } elsif ($opt eq 'w') {
                if ($arg =~ m/^\d+$/ && $arg >= 0) {
                    $lineWrap = $arg;
                    if ($lineWrap == 0) {
                        $lineWrap = 1 << 31;
                    }
                } else {
                    die("Invalid wrap length '$arg' in -w option.\n");
                }
            }
        }
    }

    #   Open input and output files

    $if = STDIN;
    $of = STDOUT;
    $ifname = "(stdin)";
    if ($#ARGV >= 0) {
        $if = IF;
        open($if, "<$ARGV[0]") || die("Cannot open input file $ARGV[0]: $!\n");
        $ifname = $ARGV[0];
    }
    if ($#ARGV >= 1) {
        $of = OF;
        open($of, ">$ARGV[1]") || die("Cannot open output file $ARGV[1]: $!\n");
    }

    $iline = 0;
    $oline = 0;

    while ($l = <$if>) {
        $iline++;

        $l1 = &demoronise($l);
        &printWrap($l1);
    }

    close($if);
    close($of);

#   demoronise  --  Translate moronic Microsoft bit-drool into
#                   vaguely readable and compatible HTML.

sub demoronise {
    local($s) = @_;
    local($i, $c);

    #   Eliminate idiot MS-DOS carriage returns from line terminator

    $s =~ s/\s+$//;
    $s .= "\n";

    #   Map strategically incompatible non-ISO characters in the
    #   range 0x82 -- 0x9F into plausible substitutes where
    #   possible.

    $s =~ s/\x82/,/g;
    $s =~ s-\x83-<em>f</em>-g;
    $s =~ s/\x84/,,/g;
    $s =~ s/\x85/.../g;

    $s =~ s/\x88/^/g;
    $s =~ s-\x89- °/°°-g;

    $s =~ s/\x8B/</g;
    $s =~ s/\x8C/Oe/g;

    $s =~ s/\x91/`/g;
    $s =~ s/\x92/'/g;
    $s =~ s/\x93/"/g;
    $s =~ s/\x94/"/g;
    $s =~ s/\x95/*/g;
    $s =~ s/\x96/-/g;
    $s =~ s/\x97/--/g;
    $s =~ s-\x98-<sup>~</sup>-g;
    $s =~ s-\x99-<sup>TM</sup>-g;

    $s =~ s/\x9B/>/g;
    $s =~ s/\x9C/oe/g;

    #   Now check for any remaining untranslated characters.

    if ($s =~ m/[\x00-\x08\x10-\x1F\x80-\x9F]/) {
        for ($i = 0; $i < length($s); $i++) {
            $c = substr($s, $i, 1);
            if ($c =~ m/[\x00-\x09\x10-\x1F\x80-\x9F]/) {
                printf(STDERR  "$ifname: warning--untranslated character 0x%02X in input line %d, output line(s) %d(...).\n",
                    unpack('C', $c), $iline, $oline + 1);
            }
        }
    }
    #   Supply missing semicolon at end of numeric entity if
    #   Billy's bozos left it out.

    $s =~ s/(&#[0-2]\d\d)\s/$1; /g;

    #   Fix dimbulb obscure numeric rendering of &lt; &gt; &amp;

    $s =~ s/&#038;/&amp;/g;
    $s =~ s/&#060;/&lt;/g;
    $s =~ s/&#062;/&gt;/g;

    #   Fix unquoted non-alphanumeric characters in table tags

    $s =~ s/(<TABLE\s.*)(WIDTH=)(\d+%)(\D)/$1$2"$3"$4/gi;
    $s =~ s/(<TD\s.*)(WIDTH=)(\d+%)(\D)/$1$2"$3"$4/gi;
    $s =~ s/(<TH\s.*)(WIDTH=)(\d+%)(\D)/$1$2"$3"$4/gi;

    #   Correct PowerPoint mis-nesting of tags

    $s =~ s-(<Font .*>\s*<STRONG>.*)(</FONT>\s*</STRONG>)-$1</STRONG></Font>-gi;

    #   Translate bonehead PowerPoint misuse of <UL> to achieve
    #   paragraph breaks.

    $s =~ s-<P>\s*<UL>-<p>-gi;
    $s =~ s-</UL><UL>-<p>-gi;
    $s =~ s-</UL>\s*</P>--gi;

    #   Repair PowerPoint depredations in "text-only slides"

    $s =~ s-<P></P>--gi;
    $s =~ s- <TD HEIGHT=100- <tr><TD HEIGHT=100-ig;
    $s =~ s-<LI><H2>-<H2>-ig;

    $s;
}

#   printWrap  --  Print one or more lines with wrap at
#                  the specified column.

sub printWrap {
    local($s) = @_;
    local($l, $sep, $rem, $ter, $lwrap, $indent);

    #   Pick the input apart line by line and reformat each line,
    #   if necessary, so as not to exceed the maximum line length.

    $s =~ m/(\s*)(\S)/;
    $indent = $1;
    if ($2 eq '<') {
        $indent .= ' ';
    }
    while (length($s) > 0) {
        if (($s =~ s/(.*\n)//) != 1) {
            $aax = $_[0];
            print("printWrap arg = |$aax|\n");
            print("printWrap s = |$s|\n");
            $aal = length($s);
            print("printWrap length(s) = $aal\n");
            die("$ifname: Error splitting lines.");
        }
        $l = $1;

        $sep = '';
        $lwrap = '';
        while (length($l) > $lineWrap) {
            if (($l =~ s/(^.{1,$lineWrap})(\s)//o) || 
                ($l =~ s/(^.{1,$lineWrap})($lineBreak1)//o) ||
                ($l =~ s/(^.{1,$lineWrap})($lineBreak2)//o)
               ) {
                $rem = $1;
                $ter = $2;
                if ($ter =~ m/\s+/) {
                    $ter='';
                }
                $lwrap .= "$sep$rem$ter\n";
                $oline++;
                $l =~ s/^\s*//;
                $sep = $indent;
            } else {
                last;
            }
        }
        print($of "$lwrap$sep$l");
        $oline++;
    }
}
