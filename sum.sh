read n
m=$n
sum=0
while [ $n -gt 0 ]
do
    read i
    sum=$((sum+i))
    #echo "add $i now $sum"
    n=$((n-1))
    #echo "n = $n"
done
echo "scale=3; $sum/$m" | bc

