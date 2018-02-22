#!/usr/bin/env python
"""
   Convert XML to HTML+CSS.
"""
import sys
from xml.sax.saxutils import escape
from optparse import OptionParser

class xml_css_formatter():
    def __init__(self,tab_width=2):
        self.tab_width = tab_width

    def format(self,content):
        # format the content and split into lines, fixing tabs in the process
        lines = content.expandtabs(self.tab_width).split('\n')

        # remove terminal empty lines
        while len(lines[-1]) == 0:
            del lines[-1]

        return "<div class='codearea'><pre>\n%s</pre></div>\n" % ("\n".join(map(escape,lines)))


def main(argv=None):

    oparser = OptionParser(usage="%prog [options]\n"
                           "or: %prog --help\n")
    oparser.add_option("-i","--input_file",dest="input_file",
                       help="input file")
    oparser.add_option("-o","--output_file",dest="output_file",
                       help="input file")
    oparser.set_defaults(input_file=None,output_file=None)

    (options,args) = oparser.parse_args(argv and argv or sys.argv)

    src = options.input_file and open(options.input_file) or sys.stdin
    out = options.output_file and open(options.output_file,'w') or sys.stdout

    out.write(xml_css_formatter().format(src.read()))

if __name__ == "__main__":
    sys.exit(main())
