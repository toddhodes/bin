#!/usr/bin/python
##!/usr/bin/env python
import sys
import urllib
from urllib import unquote

##old python
#for sL in sys.stdin.xreadlines(): print unquote(sL)
for sL in sys.stdin: print unquote(sL)

#s = sys.stdin.readline()
##print "s", s
#print unquote(s)
