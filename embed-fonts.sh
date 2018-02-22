#!/bin/bash
 
export GS_OPTIONS='-dEmbedAllFonts=true -dPDFSETTINGS=/printer'
cp $1 $1.old
pdftops $1 tmp.ps
ps2eps tmp.ps 
epstopdf tmp.eps 
mv tmp.pdf $1
rm tmp.ps tmp.eps
