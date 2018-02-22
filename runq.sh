#! /bin/sh

# standard template definitions.  We want this program to be a standalone
HOST=`hostname`
PROG=`basename $0`

ERRORS2=hodes@cs.berkeley.edu
PATH=./bin:$PATH export PATH

usage() {
	echo usage: $PROG [workload file '(default: ./runlist)'] >&2
	exit 1
}

abort() {
	echo $PROG: $@ >&2
	exit 1
}

maxtries=10
tryintvl=5
lock() {
	file=$1 ; shift
	try=0
	echo "$HOST:$$" > $file.lock.$$
	while : ; do
		if ln $file.lock.$$ $file.lock; then
			break
		fi
		sleep $tryintvl
		try=`expr $try + 1`
		if [ $try -gt $maxtries ] ; then
			rm -f $file.lock.$$
			abort "lock $file failed"
		fi
	done
	rm $file.lock.$$
}

unlock() {
	file=$1 ; shift
	if egrep "^$HOST:$$\$" $file.lock >/dev/null 2>&1 ; then
		:
	else
		msg="file $file not locked (by me?)"
		case $# in
		0)	abort $msg	;;
		*)	echo $msg >&2	;;
		esac
	fi
	rm $file.lock
}

# runq begins here...

# . ./shConfig || exit		# require lock(), unlock(), abort(), and
# 				# definition for ERRORS2

	while getopts h c 2>/dev/null ; do
	case $c in
	h|\?)	usage ;;
	esac
	done

case $# in
0)	wload=runlist		;;
1)	wload=$1 ; shift	;;
esac

[ ! -f $wload ] && abort "workload file $wload not found"

headline() {
	file=$1
	{
		read cur
		while read line ; do echo $line ; done > $file.new
		mv $file.new $file
		echo $cur
	} < $file
}

executeNextparms() {
	if [ -f .exit.$HOST -o -f .exit.all ] ; then
		return 1
	fi
	lock $wload
	if [ -s $wload ] ; then
		set `headline $wload`
	fi
	unlock $wload
	if [ "$1" ] ; then
		eval "$@" && echo `date` $@ >> $wload.out
		return 0
	else
		return 1
	fi
}

if [ -f .running.$HOST ] ; then
	echo "Simulations already running on $HOST" >&2
	exit 1
fi

while executeNextparms ; do
	: nothing
done

if [ -n "$ERRORS2" ] ; then
	Mail -s "All simulations on $HOST are complete" $ERRORS2 < /etc/motd
fi
