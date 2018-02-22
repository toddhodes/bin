find . -name \*.java | xargs grep "\t" -l | grep -v lib/build | xargs sed -i "s/^\t/   /g"
