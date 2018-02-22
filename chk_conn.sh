f ! ping -c 3 wvmrkt.com >/dev/null 2>/dev/null
then
   echo "iacxweb2 can't connect to wvmrkt.com" #| mail -s "iacxweb2 can't connect to wvmrkt.com" tom@mail20
else
   echo "it worked"
fi

