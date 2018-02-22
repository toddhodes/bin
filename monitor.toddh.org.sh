
if (ping -c 5 toddh.org ; expr $? = 0 ) >/dev/null 2>&1  
then   
 test;
else    
  ping -c 5 toddh.org 2>&1 | mail -s "[Alert] toddh.org is down" todd@locationlabs.com
fi
