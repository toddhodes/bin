#!/usr/bin/perl -w
#- Bin2Hex.pl
#- Copyright (c) 1995 by Dr. Herong Yang
#
   #($in, $out) = @ARGV;
   $in = $ARGV[0];
   die "Missing input file name.\n" unless $in;
   #die "Missing output file name.\n" unless $out;
   $byteCount = 0;
   open(IN, "< $in");
   binmode(IN);
   #open(OUT, "> $out");
   print ("        ");
   while (read(IN,$b,1)) {
      $n = length($b);
      $byteCount += $n;
      #$s = 2*$n;
      #print (OUT unpack("H$s", $b), "\n");
      #print ("0x", unpack("j$s", $b), " ");
      #print ($b);
      $i = unpack("c", $b);
      if($i > 128){ $i = $i - 128; }
      if(length($i) == 1 ) { print ("   "); }
      if(length($i) == 2 ) { print ("  "); }
      if(length($i) == 3 ) { print (" "); }
      print ($i, ", ");

      #print (unpack("H$s", $b), " ");
      if($byteCount % 8 == 0) { print ("\n        "); }
   }
   print ("\n");
   close(IN);
   #close(OUT);
   print "Number of bytes converted = $byteCount\n";
   exit;
