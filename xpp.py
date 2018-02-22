#!/usr/bin/env python
import sys
from xml.dom.ext.reader.Sax2 import FromXmlStream
from xml.dom.ext import PrettyPrint

# get DOM object
doc = FromXmlStream(sys.stdin)

PrettyPrint(doc)
