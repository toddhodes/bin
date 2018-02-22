#!/usr/sww/bin/perl

#This is the final version of Daily Update.  It grabs info from the weather
#server in Michigan, the Dilbert page, and Yahoo's headlines and spits it out
#in html format.
#
#If you want to speed up the gifs, change the $imagedir variable below and
#copy *.gif to the new location.  For example, file:/blah/blah2/loc/.
#
#Feel free to modify the code, but please leave my name on it, since I'm so
#damned proud of my first script ever.  Which brings me to my second point:
#if you can do it better, feel free to share your way with me, but remember
#*this is my first script*.
#
#Written by: David Coppit  http://www.cs.virginia.edu/~dwc3q/index.html
#Modified by:
#---------------------------------------------------------------------------
$imagedir = "http://www.cs.virginia.edu/~dwc3q/images/";
$tempsdir = "./";

print "<html>\n";
print "<head><title>The Daily Update</title></head>\n";
print "<body text=\"#ffffff\" link=\"#ffffcc\" vlink=\"#ffccff\" alink=";
print "\"0000dd\"\n";
print " background=\"http://www.cs.virginia.edu/~dwc3q/images/";
print "backgrounds/paper_bluewhite.gif\">\n";
print "\n";

print "<table width=100%>\n";
print "<tr>\n";
print " <td> <a href=\"http://lycos.cs.cmu.edu/\">\n";
print ("  <img src=\"",$imagedir,"lycos.gif\" alt=\"Lycos\" border=0></a></td>\n");
print " <td align=center><h2>The Daily Update</h2>\n";

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
#if ($hour > 12) {$hour = $hour - 12;
#                 $am_pm = pm}
#else
#                 {$am_pm = am}
#
#print ("<h4>",$hour,":");
#if ($min < 10) {print "0"};
#print ($min,$am_pm,"  ");
if ($wday eq 0) {print("Sunday, ")};
if ($wday eq 1) {print("Monday, ")};
if ($wday eq 2) {print("Tuesday, ")};
if ($wday eq 3) {print("Wednesday, ")};
if ($wday eq 4) {print("Thursday, ")};
if ($wday eq 5) {print("Friday, ")};
if ($wday eq 6) {print("Saturday, ")};

if ($mon eq 0) {print("January ",$mday,".")}
if ($mon eq 1) {print("February ",$mday,".")}
if ($mon eq 2) {print("March ",$mday,".")}
if ($mon eq 3) {print("April ",$mday,".")}
if ($mon eq 4) {print("May ",$mday,".")}
if ($mon eq 5) {print("June ",$mday,".")}
if ($mon eq 6) {print("July ",$mday,".")}
if ($mon eq 7) {print("August ",$mday,".")}
if ($mon eq 8) {print("September ",$mday,".")}
if ($mon eq 9) {print("October ",$mday,".")}
if ($mon eq 10) {print("November ",$mday,".")}
if ($mon eq 11) {print("December ",$mday,".")}

print "  </h4></center>\n";
print "</tr>\n";
print "</table>\n\n";

print "<hr size=2 noshade>\n\n";

print "<h3>The Weather</h3>\n"; 

if (!open(WEATHERFILE,join("",$tempsdir,"weather.temp")))
    {die "\nERROR: Can not open ",$tempsdir,"weather.temp.\n\n"};

$line = <WEATHERFILE>; 
#Get time of current report.  
#print (substr($line,index($line," at ")+4, 
# index($line," EDT ")-index($line," at ")-4));

$_ = <WEATHERFILE>;
$_ = <WEATHERFILE>;

$line = <WEATHERFILE>;
print "<table width=100%>\n";
print "<tr>\n";
print " <th>\n";
print " <th> SKIES\n";
print " <th> TEMPERATURE\n";
print " <th> WINDS\n";
print "</tr>\n\n";
print "<tr>\n";
print " <th> CURRENTLY\n";
if ($line =~ / *(\S*)$/) {$_ = $1;
                          tr/a-z/A-Z/;
                          if ($_ =~ /N\/A/) {$_ = "NOT AVAILABLE"};
                          print (" <td> ",$_,"</td>\n")};
if ($line =~ /^ *(\d+)/) {print (" <td> ",$1,"</td>\n")};
if ($line =~ / *\S* *\S* *(\S* .. \S*)/) {$_ = $1;
                                          tr/a-z/A-Z/;
                                          print (" <td> ",$_,"</td>\n")};
print "</tr>\n\n";


do {
 $_ = <WEATHERFILE>;
 } until $_ =~ /^ /;
$line = <WEATHERFILE>;

do {
print "<tr>\n";
if ($line =~ /^ ([A-Z ]*)\./) {print (" <th> ",$1,"\n")};
if ($line =~ /^[A-Z ]*\.\.\.([A-Z ]*)\./) {print (" <td> ",$1,"</td>\n")};
if ($line =~ /^[A-Z ]*\.\.\.[A-Z0-9 ]*\. ([A-Z0-9 ]*)\.[ \n]/) {print (" <td> ",$1,"</td>\n")}
 elsif
($line =~ /^.*\. ([A-Z0-9 ]*)$/) {print (" <td> ",$1," ");
                              $line = <WEATHERFILE>;
                              if ($line =~ /^([A-Z0-9 ]*)\./) {print ($1,"</td>\n")};};
                              if ($line =~ /^[A-Z0-9 ]*\. (.*)\./) 
                               {print ("<td> ",$1,"</td>\n")};
if ($line =~ /^ [A-Z0-9 ]*\.\.\.[A-Z0-9 ]*\. [A-Z0-9 ]*\. (.*)\./)
 {print (" <td> ",$1,"</td>\n")}
 elsif
($line =~ /^ [A-Z0-9 ]*\.\.\.[A-Z0-9 ]*\. [A-Z0-9 ]*\. (.*)\n/)
 {print (" <td> ",$1," ");
                               $line = <WEATHERFILE>;
                               print (substr($line,0,length($line)-2),"</td>\n");};
print "</tr>\n\n";
$line = <WEATHERFILE>;
} until $line =~ /^\n/;

print "</table><hr size=2 noshade>\n\n";
close (WEATHERFILE);

print "<h3>Dilbert</h3>\n";
print "<center>\n";
print "<img src=\"http://www.unitedmedia.com/comics/dilbert/todays_dilbert.gif\" alt=\"Dilbert Strip\" width=600 height=219>\n";
print "</center>\n\n";

print "<hr size=2 noshade>\n";

if (!open(NEWSFILE,join("",$tempsdir,"news.temp"))) 
   {die "\nERROR: Can not open ",$tempsdir,"news.temp.\n\n"};
do{
 $line = <NEWSFILE>;
} until $line =~ /<h2>Headlines<\/h2>/;

print "<h3>Headlines</h3>\n";
do{
 $line = <NEWSFILE>;
 if ($line =~ /.*="\//) {
  $_ = $line;
  s/="\//\="http:\/\/www.yahoo.com\//;
  print ($_);
 }
} until $line =~ /^<\/ul>/;

print "<hr size=2 noshade>";
print "<font size=-1><address><a href=\"http://www.cs.virginia.edu/~dwc3q/index.html\">";
print "</body></html>\n";
