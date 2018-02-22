
cat /tmp/wiki | while read i
do
  n=`echo $i | cut -d\| -f2`
  des=`echo $i | cut -d\| -f3`
  trig=`echo $i | cut -d\| -f4`
  res=`echo $i | cut -d\| -f5`
  echo "  <!-- @Name: $n"
  echo "     - @Description: $des"
  echo "     - @Trigger: $trig"
  echo "     - @Result: $res -->"
done

