#!/usr/bin/env python
import sys
import urllib
from urllib import unquote, quote

for sL in sys.stdin: print quote(sL)

#s = sys.stdin.readline()
##print "s", s
#print quote(s)
