#!/usr/bin/env python
"""
   Convert Java to HTML+CSS.

   Implemented using regular expressions, based on the implementation used
   in the MoinMoin wiki. Regular expressions provide a cheap alternative to
   using a lexer-parser like antlr that actually understands Java syntax.

   Using a lexer-parser would allow some improvement, however. The current
   implementation cannot readily identify method or variable name declarations.
"""
import re
import sys
import cgi
from optparse import OptionParser

JAVA_TYPES = [ 'byte','int','long','float','double','char','short','void','boolean' ]
JAVA_RESERVED_WORDS = ['class','interface','enum','import','package',
                       'static','final','const','private','public','protected',
                       'new','this','super','abstract','native','synchronized','transient','volatile','strictfp',
                       'extends','implements','if','else','while','for','do','switch','case','default','instanceof',
                       'try','catch','finally','throw','throws','return','continue','break']
JAVA_CONSTANTS = ['true','false','null']

class java_rule(object):
    """
    Rule using a regular expression to insert a <span> tag around matching content.
    """
    def __init__(self,name,label,start,end=None):
        self.name = name
        self.label = label
        self.start = start
        self.end = end and re.compile(end) or None
        # Same the rule's (unique) name in the regular expression
        self.named_pattern = "(?P<%s>%s)" % (self.name, self.start)

class css_formatter(object):
    def format(self,content):
        return "<style type='text/css'>\n%s</style>\n" % (content)

class java_formatter(object):
    def __init__(self):
        self.rules = []
        self.name_rules = {}

        word = lambda x: "\\b%s\\b" % x

        # In-line comments
        self.add_rule(java_rule('InlineComment','Comment',"//.*$"))
        # Block comments
        self.add_rule(java_rule('BlockComment','Comment',"/[*]","[*]/"))
        # String literals
        self.add_rule(java_rule('String','String','"',r'$|[^\\](\\\\)*"'))
        # Reserved words
        self.add_rule(java_rule('Reserved','Reserved',"|".join(map(word,JAVA_RESERVED_WORDS))))
        # Built-in types
        self.add_rule(java_rule('Type','Type',"|".join(map(word,JAVA_TYPES))))
        # Constants
        self.add_rule(java_rule('Constant','Constant',"|".join(map(word,JAVA_CONSTANTS))))
        # Character literals
        self.add_rule(java_rule('Character','Char',r"'\\.'|'[^\\]'"))
        # Numeric constants
        self.add_rule(java_rule('Number','Number',r"[0-9](\.[0-9]*)?(eE[+-][0-9])?[flFLdD]?|0[xX][0-9a-fA-F]+[Ll]?"))
        # Package
        self.add_rule(java_rule('Package','Package',"([a-zA-Z_][0-9a-zA-Z_]*[.])+([*]|[A-Z][0-9a-zA-Z_]*)"))
        # Classes
        self.add_rule(java_rule('Class','Type',"[A-Z][0-9a-zA-Z_]*"))
        # Variable
        #self.add_rule(java_rule('Variable','Variable',"\\b[a-zA-Z_][0-9a-zA-Z_]*\\b"))
        # Identifiers
        self.add_rule(java_rule('Identifier','Identifier',"[a-zA-Z_][0-9a-zA-Z_]*"))
        # Special characters
        self.add_rule(java_rule('Special','Special',r"[~!%^&*()+=|\[\]:;,.<>/?{}-]+"))

        # Construct a regular expresion from all of the above rules
        self.pattern = re.compile("|".join([rule.named_pattern for rule in self.rules]),re.MULTILINE)

    def add_rule(self,rule):
        self.rules.append(rule)
        self.name_rules[rule.name] = rule

    def get_next(self,data,formatter):
        """
        Generator that returns and formats the next matching code segment
        """
        pos = 0
        # Starting at the beginning of the data, try to match our rules
        match = self.pattern.search(data,pos)
        while match and pos < len(data):
            # Return content before match
            yield data[pos:match.start()]
            pos = match.start()
            # Retrieve the matching text and the rule name
            for name, text in match.groupdict().items():
                if not text: continue
                # Retrieve the rule
                rule = self.name_rules[name]
                if rule.end:
                    # If the rule defines an end match, look for it
                    end_match = rule.end.search(data,pos)
                    if not end_match:
                        # No end match, match everything
                        last = len(data)
                    else:
                        # Found end match, calculate end position
                        last = end_match.end() + (end_match.end() == pos)
                    # Match covers this new range
                    text = data[pos:last]
                    pos = last
                else:
                    pos = match.end() + (match.end() == pos)
                # Format the matching text, checking for multiline matches
                first = True
                for line in text.split('\n'):
                    if first:
                        first = False
                    else:
                        yield '\n'
                    yield formatter.format(line,rule)
                        
            match = self.pattern.search(data,pos)
        # Return everything after the last match
        yield data[pos]

    def format(self,content,formatter):
        return "".join(self.get_next(content,formatter))
    
class css_rule_formatter(object):
    def format(self,content,rule):
        return "<span class='%s'>%s</span>" % (rule.label,cgi.escape(content))

class java_css_formatter(java_formatter):
    def __init__(self,tab_width=2):
        java_formatter.__init__(self)
        self.tab_width = tab_width

    def format(self,content):
        # format the content and split into lines, fixing tabs in the process
        formatter = css_rule_formatter()
        lines = java_formatter.format(self,content,formatter).expandtabs(self.tab_width).split('\n')

        # remove terminal empty lines
        while len(lines[-1]) == 0:
            del lines[-1]

        # define a mechanism for line numbering
        global line_number
        line_number = 0
        def get_line_number():
            global line_number
            line_number += 1
            return line_number
        def number(line):
            return "<span class='Line'><span class='LineNumber'>%-3d </span>%s</span>\n" % (get_line_number(),line)

        return "".join(["<div class='codearea'><pre>\n%s</pre></div>\n" % ("".join(map(number,lines))),
                        "<a href='#' class='toggle' onclick='return togglenumber();'>Toggle line numbers</a>"])


def main(argv=None):

    oparser = OptionParser(usage="%prog [options]\n"
                           "or: %prog --help\n")
    oparser.add_option("-i","--input_file",dest="input_file",
                       help="input file")
    oparser.add_option("-o","--output_file",dest="output_file",
                       help="input file")
    oparser.add_option("-c","--css",dest="css_file",
                       help="css file")
    oparser.set_defaults(input_file=None,output_file=None,css_file=None)

    (options,args) = oparser.parse_args(argv and argv or sys.argv)

    src = options.input_file and open(options.input_file) or sys.stdin
    out = options.output_file and open(options.output_file,'w') or sys.stdout

    if options.css_file:
        css = open(options.css_file)
        out.write(css_formatter().format(css.read()))
        
    out.write(java_css_formatter().format(src.read()))

if __name__ == "__main__":
    sys.exit(main())
