
#
# (bugs/questions --> todd)
#

usage () { 
  echo
  echo "usage $0 <old-id> <new-id>" 
  echo
  echo " --- SETUP ---"
  echo
  echo "make sure you have NO PROGRAMS RUNNING, especially X win programs,"
  echo "  except as root;  ie, logout completely and login root on console."
  echo 
  echo
  echo "either get YP / NIS up and running first" 
  echo
  echo "                    OR"
  echo
  echo "in /etc/group --> add engr:x:5000:"
  echo "in /etc/passwd --> change your uid to your new globally unique one"
  echo
  echo "   then run this program as the usage msg indicates"
  exit 
}

if [ x$1 = x ]
then
  usage
fi

if [ x$2 = x ]
then
  usage
fi

engr=`grep ^engr: /etc/group | cut -d: -f3`
if [ ! x$engr = x5000 ]
then
  yengr=`ypcat group | grep ^engr: | cut -d: -f3`
  if [ ! x$yengr = x5000 ]
  then
    echo "you seem not to have access to the engr group as 5000" 
    echo "(i'm getting engr gid entries as '$engr' and ''$yengr')"
    echo
    echo "so i assume something is wrong.  exiting."
    exit
  fi
fi
unset engr yengr

oldid=$1
newid=$2

find / -mount -uid $oldid -print > /tmp/ownedby-$oldid

while read i
do
  chown $newid:engr "$i"
done  < /tmp/ownedby-$oldid

echo "finished changing $oldid uids"


## -- to ignore bad groups - exit here
#exit

find / -mount -group $oldid -print > /tmp/groupis-$oldid

while read i
do
  chgrp engr "$i"
done  < /tmp/groupis-$oldid

echo "finished changing $oldid gids"
echo
echo "leaving /tmp/ownedby-$oldid and /tmp/groupis-$oldid around for perusal"

unset oldid newid i

