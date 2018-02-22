#!/usr/sww/bin/perl

# Usage: $0 file1 file2 ...

while (<>) {
        $val{$1}++ if /(\w+)/
        }

foreach $key (keys %val) {
        print "$val{$key} $key\n";
        }

