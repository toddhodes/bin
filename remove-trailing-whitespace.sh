

for i in ` find . -name \*.java | xargs grep "[ ]*$" -l  | grep -v lib/build` 
do    
  perl -p -i -e 's/[ ]*$//g' $i
done

#for i in ` find . -name \*.java | xargs grep "^[ ]+$" -l  | grep -v lib/build` 
#do    
#  perl -p -i -e 's/^[ ]+$//g' $i
#done

