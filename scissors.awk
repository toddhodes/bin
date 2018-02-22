#!/usr/bin/awk -f
# cuts between ----------------8<--------------- marks

{if($0 ~ /-----8<-----/)switch++;else if(switch%2==1)print $0}


#--
#!/usr/bin/awk -f
#BEGIN{n=ARGV[2];ARGV[2]=""}{if($0 ~ /---8<---/)sw++;else if(sw==n*2-1)print $0}
#--
#awk '{if($0 ~ /-----8<-----/)switch++;else if(switch==1)print $0}' < $1 > $2

