# hunt
# looks for a user on the machines listed below.
#
# If no command argument is specified, displays all users on all
# of the machines.
#
# If no search string is specified, displays all users on given machines.
# 
#
# Scott Evans 
# thrash@virginia.edu


CS_LIST="@opal.cs @poplar.cs @jade.cs @topaz.cs @oak.cs @ash.cs \
@maple.cs @onyx.cs @beech.cs @garnet.cs"

SUNLAB_LIST="@helga1.acc @helga2.acc @helga3.acc @helga4.acc @helga5.acc \
@helga6.acc @helga7.acc @helga8.acc @helga9.acc  @helga10.acc \
@helga11.acc @helga12.acc @helga13.acc \
@honi1.acc @honi2.acc @honi3.acc @honi4.acc @honi5.acc @honi6.acc @honi7.acc \
@hagar4.acc @hagar5.acc @hagar6.acc @hagar7.acc @hagar8.acc @hagar9.acc \
@hagar10.acc"

RS6000_LIST="@holmes.acc @fulton.seas.virginia.edu @kelvin.seas.virginia.edu \
@fermi.clas.virginia.edu @faraday.clas.virginia.edu @poe.acc.virginia.edu" 

ALL="$CS_LIST $SUNLAB_LIST $RS6000_LIST"


if [ $# -eq 0 ] ; then 
	finger $ALL

else 
    for i in "$@" ; do
	case $i in
		(-cs) 		FINGERLIST="$FINGERLIST $CS_LIST" ;;
		(-sunlab) 	FINGERLIST="$FINGERLIST $SUNLAB_LIST" ;;
		(-rs6000)	FINGERLIST="$FINGERLIST $RS6000_LIST" ;;
		(-all) 		FINGERLIST=$ALL ;;
		(-*) 		echo "Usage: ${0} [-rs6000] [-sunlab] [-cs] [-all] [search string]"; exit ;;
		(*)		 SEARCHSTRING=$i ;;
	esac
    done

	if [ -z "$FINGERLIST" ] ; then
		FINGERLIST=$ALL
	fi

	if [ -z "$SEARCHSTRING" ] ; then
		finger $FINGERLIST
		exit
	fi

		
	finger $FINGERLIST |
	nawk ' 	(substr($0,1,1)=="\[") {printed=0
					machine=$0
		}

		(index($0,TARGET)!=0) {	if (printed==0) {
						print machine
#						print $0 # comment this line
							 # out if you just 
							 # want the machines to
							 # be displayed, and not
							 # the name info
						printed=1
						printf("\n")
					}
		}
		' TARGET=$SEARCHSTRING

fi
