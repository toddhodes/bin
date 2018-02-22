
# Game values
# 0 - Dominoes
# 1 - Queens
# 2 - Last 2
# 3 - King of Hearts
# 4 - Hearts
# 5 - Tricks
# 6 - Trumps Spades
# 7 - Trumps Hearts
# 8 - Trumps Dmonds
# 9 - Trumps Clubs

proc InitGameVariables {} {
    global gvars;

    set gvars(numplayers) 0;

    set gvars(n,name) "";
    set gvars(s,name) "";
    set gvars(e,name) "";
    set gvars(w,name) "";

    set gvars(n,chann) "";
    set gvars(s,chann) "";
    set gvars(e,chann) "";
    set gvars(w,chann) "";
}

proc Register {name} {
    global gvars;
    global dp_rpcFile;

    puts "In register"

    set name [string tolower $name];

    if {$gvars(numplayers) == 4} {
	return;
    }

    if {$name == ""} {
	return;
    }

    set rval [expr [clock clicks] % 4];

    set not_done 1;

    while {$not_done} {
	switch $rval {
	    0 {
		if {$gvars(n,name) == ""} {
		    set gvars(n,name) $name;
		    set gvars(n,chann) $dp_rpcFile;
		    set not_done 0;
		} else {
		    set rval [expr ($rval + 1) % 4];
		}
	    }
	    1 {
		if {$gvars(s,name) == ""} {
		    set gvars(s,name) $name;
		    set gvars(s,chann) $dp_rpcFile;
		    set not_done 0;
		} else {
		    set rval [expr ($rval + 1) % 4];
		}
	    }
	    2 {
		if {$gvars(e,name) == ""} {
		    set gvars(e,name) $name;
		    set gvars(e,chann) $dp_rpcFile;
		    set not_done 0;
		} else {
		    set rval [expr ($rval + 1) % 4];
		}
	    }
	    3 {
		if {$gvars(w,name) == ""} {
		    set gvars(w,name) $name;
		    set gvars(w,chann) $dp_rpcFile;
		    set not_done 0;
		} else {
		    set rval [expr ($rval + 1) % 4];
		}
	    }
	}
    }

    incr gvars(numplayers) 1;

    if {$gvars(numplayers) == 4} {
	# Rerandomize seat positions.

	set rval [expr [clock clicks] % 3];
	switch $rval {
	    0 {set rpos s}
	    1 {set rpos e}
	    2 {set rpos w}
	}
	set tmp_name $gvars(n,name);
	set tmp_chann $gvars(n,chann);
	set gvars(n,name) $gvars($rpos,name);
	set gvars(n,chann) $gvars($rpos,chann);
	set gvars($rpos,name) $tmp_name;
	set gvars($rpos,chann) $tmp_chann;

	set rval [expr [clock clicks] % 2];
	switch $rval {
	    0 {set rpos e}
	    1 {set rpos w}
	}
	set tmp_name $gvars(s,name);
	set tmp_chann $gvars(s,chann);
	set gvars(s,name) $gvars($rpos,name);
	set gvars(s,chann) $gvars($rpos,chann);
	set gvars($rpos,name) $tmp_name;
	set gvars($rpos,chann) $tmp_chann;


	# Force AI's to be westward

	set tmp_cntr 0;
	while {[string first "ai" $gvars(n,name)] == 0} {
	    if {$tmp_cntr > 3} {
		break;
	    }
	    set tmp_name $gvars(n,name);
	    set tmp_chann $gvars(n,chann);
	    set gvars(n,name) $gvars(e,name);
	    set gvars(n,chann) $gvars(e,chann);
	    set gvars(e,name) $gvars(s,name);
	    set gvars(e,chann) $gvars(s,chann);
	    set gvars(s,name) $gvars(w,name);
	    set gvars(s,chann) $gvars(w,chann);
	    set gvars(w,name) $tmp_name;
	    set gvars(w,chann) $tmp_chann;
	    incr tmp_cntr;
	}

	set tmp_cntr 0;
	while {[string first "ai" $gvars(e,name)] == 0} {
	    if {$tmp_cntr > 2} {
		break;
	    }
	    set tmp_name $gvars(e,name);
	    set tmp_chann $gvars(e,chann);
	    set gvars(e,name) $gvars(s,name);
	    set gvars(e,chann) $gvars(s,chann);
	    set gvars(s,name) $gvars(w,name);
	    set gvars(s,chann) $gvars(w,chann);
	    set gvars(w,name) $tmp_name;
	    set gvars(w,chann) $tmp_chann;
	    incr tmp_cntr;
	}


	set tmp_cntr 0;
	while {[string first "ai" $gvars(s,name)] == 0} {
	    if {$tmp_cntr > 1} {
		break;
	    }
	    set tmp_name $gvars(s,name);
	    set tmp_chann $gvars(s,chann);
	    set gvars(s,name) $gvars(w,name);
	    set gvars(s,chann) $gvars(w,chann);
	    set gvars(w,name) $tmp_name;
	    set gvars(w,chann) $tmp_chann;
	    incr tmp_cntr;
	}

	StartGame;
    }
}

proc Broadcast {cmd} {
    global gvars;

    eval dp_RDO $gvars(n,chann) $cmd;
    eval dp_RDO $gvars(e,chann) $cmd;
    eval dp_RDO $gvars(s,chann) $cmd;
    eval dp_RDO $gvars(w,chann) $cmd;
}

proc StartGame {} {
    global gvars;

    dp_RDO $gvars(n,chann) InitGameBoard $gvars(n,name) $gvars(e,name) $gvars(s,name) $gvars(w,name);

    dp_RDO $gvars(e,chann) InitGameBoard $gvars(e,name) $gvars(s,name) $gvars(w,name) $gvars(n,name);

    dp_RDO $gvars(s,chann) InitGameBoard $gvars(s,name) $gvars(w,name) $gvars(n,name) $gvars(e,name);

    dp_RDO $gvars(w,chann) InitGameBoard $gvars(w,name) $gvars(n,name) $gvars(e,name) $gvars(s,name);

    Broadcast "InitScoreboard $gvars(n,name) $gvars(e,name) $gvars(s,name) $gvars(w,name)";

    Broadcast InitChat
    
    SetupDealer n

    StartPlay;
}

proc SetupDealer {dealer} {
    global gvars;

    ClearUIs

    set gvars(cur_dealer) $dealer;

    ClearReqDbls;
    ClearGameList;

    Broadcast "SetDealer $gvars($dealer,name)";
}
    
proc StartPlay {} {
    global gvars;

    ClearUIs

    set dealer $gvars(cur_dealer);

    Broadcast "SetPlayTurn $gvars($dealer,name)"

    ClearDblMatrix;

    Broadcast "SetGMsg \"$gvars($dealer,name) is choosing a game.\"";
    
    set glist [GetGameList];

    set deck [Shuffle];

    dp_RDO $gvars(n,chann) SetHand [lrange $deck 0 12];
    set gvars(n,hand) [lrange $deck 0 12];

    dp_RDO $gvars(s,chann) SetHand [lrange $deck 13 25];
    set gvars(s,hand) [lrange $deck 13 25];

    dp_RDO $gvars(e,chann) SetHand [lrange $deck 26 38];
    set gvars(e,hand) [lrange $deck 26 38];

    dp_RDO $gvars(w,chann) SetHand [lrange $deck 39 51];
    set gvars(w,hand) [lrange $deck 39 51];


    dp_RDO $gvars($dealer,chann) DoGameChoice $glist;
}

proc ReportDominoesRankChoice {rank} {
    global gvars;

    switch $rank {
	9 {set value Jack}
	10 {set value Queen}
	11 {set value King}
	12 {set value Ace}
	default {set value [expr $rank+2]}
    }

    set gname [GetGameName 0];
    set gmsg "from the $value.";

    Broadcast "SetGame $gname \"$gmsg\"";
    Broadcast "InitDominoes $rank";
    Broadcast PackForDominoes



    set gvars(cur_game) 0;

    switch $gvars(cur_dealer) {
	n {set firstDblr e}
	e {set firstDblr s}
	s {set firstDblr w}
	w {set firstDblr n}
    }
	
    set gvars(dbl_cntr) 0;
    set gvars(dominoes_start) $value;

    StartDoubling $firstDblr;
}


proc ReportGameChoice {gvalue} {
    global gvars;

    MarkGame $gvalue;

    if {$gvalue == 0} {
	dp_RDO $gvars($gvars(cur_dealer),chann) DoDominoesRankChoice;
	return;
    }

    set gname [GetGameName $gvalue];
    set gmsg [GetGameMsg $gvalue];

    if {$gvalue >= 6} {
	switch $gvalue {
	    6 {Broadcast {SetTrump 0}}
	    7 {Broadcast {SetTrump 1}}
	    8 {Broadcast {SetTrump 2}}
	    9 {Broadcast {SetTrump 3}}
	}
    }
		
    Broadcast "SetGame \"$gname\" \"$gmsg\"";

    set gvars(cur_game) $gvalue;

    switch $gvars(cur_dealer) {
	n {set firstDblr e}
	e {set firstDblr s}
	s {set firstDblr w}
	w {set firstDblr n}
    }
	
    set gvars(dbl_cntr) 0;

    Broadcast ClearTable;
    Broadcast PackForTricks;

    StartDoubling $firstDblr;
}

proc StartDoubling {dblr} {
    global gvars;

    if {$gvars(dbl_cntr) == 7} {
	ReflectDblMatrix;
	StartCardPlaying;
	return;
    }

    if {$gvars(dbl_cntr) < 3} {
	Broadcast "SetGMsg \"$gvars($dblr,name) is doubling.\"";

	set dlist [GetDblList $dblr];
	set dbls_owed $gvars($dblr,reqdbls);
	set dbls_forced 0;
	foreach entry $dlist {
	    if {[lindex $entry 2] == 1} {
		set dbls_forced 1;
	    }
	}

	if {$dbls_forced} {
	    set msg2 "You must double dealer!";
	} else {
	    switch $dbls_owed {
		0 {set msg2 "You need not double dealer."}
		1 {set msg2 "You owe dealer 1 double."}
		2 {set msg2 "You owe dealer 2 doubles."}
	    }
	}
	
	dp_RDO $gvars($dblr,chann) DoDoubleDlog "Who do you wish to (re)double?" \
		$msg2 $dlist;
    } else {
	set dlist [GetReDblList $dblr];

	if {$dlist == ""} {
	    switch $dblr {
		n {set dblr e}
		e {set dblr s}
		s {set dblr w}
		w {set dblr n}
	    }
	    incr gvars(dbl_cntr);
	    StartDoubling $dblr;
	} else {
	    Broadcast "SetGMsg \"$gvars($dblr,name) is redoubling.\"";
	    dp_RDO $gvars($dblr,chann) DoDoubleDlog "Redoubles?" "" $dlist;
	}
    }
}

proc ReportDoubles {name dlist} {
    global gvars;

    foreach entry $dlist {
	set dname [lindex $entry 0]
	set dvalue [lindex $entry 1]

	if {[string first "ai" $dname] != 0} {
	    MarkDbl $name $dname $dvalue;
	}
    }

    set msg [ConstructDblMsg $name $dlist];

    Broadcast "PostChatMsg system {$msg}";

    incr gvars(dbl_cntr);

    switch $name \
	    $gvars(n,name) {
	set dblr e;
    } \
	    $gvars(e,name) {
	set dblr s;
    } \
	    $gvars(s,name) {
	set dblr w;
    } \
	    $gvars(w,name) {
	set dblr n;
    }

    StartDoubling $dblr;
}
    
proc StartCardPlaying {} {
    global gvars;

    set dealer $gvars(cur_dealer);

    Broadcast "SetLastCard $gvars(n,name) {} 0";
    Broadcast "SetLastCard $gvars(e,name) {} 0";
    Broadcast "SetLastCard $gvars(s,name) {} 0";
    Broadcast "SetLastCard $gvars(w,name) {} 0";

    set gvars(n,score) 0;
    set gvars(s,score) 0;
    set gvars(e,score) 0;
    set gvars(w,score) 0;

    global dblmatrix;

    foreach p1 {n s e w} {
	foreach p2 {n s e w} {
	    if {$p1 != $p2} {
		switch $dblmatrix($p1,$p2) {
		    0 {
			dp_RDO $gvars($p1,chann) SetMsgThree $gvars($p2,name) {};
		    }
		    1 {
			dp_RDO $gvars($p1,chann) SetMsgThree $gvars($p2,name) {Doubled};
		    }
		    2 {
			dp_RDO $gvars($p1,chann) SetMsgThree $gvars($p2,name) {Redoubled};
		    }
		}
	    }
	}
    }

    switch $gvars(cur_game) {
	0 {
	    # Dominoes

	    Broadcast "SetMsgOne $gvars(n,name) {13 left}";
	    Broadcast "SetMsgOne $gvars(e,name) {13 left}";
	    Broadcast "SetMsgOne $gvars(s,name) {13 left}";
	    Broadcast "SetMsgOne $gvars(w,name) {13 left}";

	    set gvars(n,left) 13;
	    set gvars(s,left) 13;
	    set gvars(e,left) 13;
	    set gvars(w,left) 13;

	    set gvars(dom_num_out) 0;

	    Broadcast "SetPlayMode 1";
	    Broadcast "SetGMsg {Game is under way.}"
	}
	default {
	    # All others

	    Broadcast "SetMsgOne $gvars(n,name) {0 tricks}";
	    Broadcast "SetMsgOne $gvars(e,name) {0 tricks}";
	    Broadcast "SetMsgOne $gvars(s,name) {0 tricks}";
	    Broadcast "SetMsgOne $gvars(w,name) {0 tricks}";

	    Broadcast "SetPlayMode 1";
	    Broadcast "SetGMsg {Game is under way.}"

	    set gvars(cur_lead) $dealer;
	    set gvars(n,cur_card) "";
	    set gvars(e,cur_card) "";
	    set gvars(s,cur_card) "";
	    set gvars(w,cur_card) "";

	    set gvars(cur_trick,num_played) 0;
	    set gvars(num_tricks_played) 0;

	    set gvars(n,ntricks) 0;
	    set gvars(s,ntricks) 0;
	    set gvars(e,ntricks) 0;
	    set gvars(w,ntricks) 0;

	    set gvars(queensout) 0;
	    set gvars(hrtsout) 0;
	}
    }

    AdvancePlayer $gvars(cur_dealer);
}	    
	    
proc ReportCard {name card} {
    global gvars;

    set seatpos [MapNameToSeat $name];

    switch $seatpos {
	n {set nextpos e}
	e {set nextpos s}
	s {set nextpos w}
	w {set nextpos n}
    }

    if {$card != ""} {
	Broadcast "PostPlay $name $card";
	# Update server's notion of what is in whose hand

	set idx [lsearch $gvars($seatpos,hand) $card];
	if {$idx != -1} {
	    set gvars($seatpos,hand) [lreplace $gvars($seatpos,hand) $idx $idx];
	} else {
	    puts "Hand inconsistency";
	}
    }

    switch $gvars(cur_game) {
	0 {
	    # Dominoes
	    
	    if {$card != ""}  {
		incr gvars($seatpos,left) -1;
	    
		Broadcast "SetMsgOne $gvars($seatpos,name) \"$gvars($seatpos,left) left\"";
		Broadcast "SetLastCard $gvars($seatpos,name) $card 0";

		if {$gvars($seatpos,left) == 0} {
		    switch $gvars(dom_num_out) {
			0 {
			    set gvars($seatpos,score) 45;
			}
			1 {
			    set gvars($seatpos,score) 20;
			}
			2 {
			    set gvars($seatpos,score) 5;
			}
			3 {
			    set gvars($seatpos,score) -5;
			}
		    }
		    incr gvars(dom_num_out);
		}
	    }

	    if {$gvars(dom_num_out) == 4} {
		set time [clock seconds];
		while {[clock seconds] < [expr $time + 2]} {
		    update;
		}
		DoEndGame
	    } else {
		AdvancePlayer $nextpos;
	    }
	}
	default {
	    # All the rest (trick games).
	    
	    set gvars($seatpos,cur_card) $card;
	    incr gvars(cur_trick,num_played);

	    if {$gvars(cur_trick,num_played) == 4} {
		set time [clock seconds];
		while {[clock seconds] < [expr $time + 2]} {
		    update;
		}
		CollectTrick;
	    } else {
		AdvancePlayer $nextpos;
	    }
	}
    }
}

proc ClearUIs {} {
    global gvars;

    Broadcast "SetMsgOne $gvars(n,name) {}";
    Broadcast "SetMsgOne $gvars(e,name) {}";
    Broadcast "SetMsgOne $gvars(s,name) {}";
    Broadcast "SetMsgOne $gvars(w,name) {}";

    Broadcast "SetMsgThree $gvars(n,name) {}";
    Broadcast "SetMsgThree $gvars(e,name) {}";
    Broadcast "SetMsgThree $gvars(s,name) {}";
    Broadcast "SetMsgThree $gvars(w,name) {}";
}

proc ClearReqDbls {} {
    global gvars;

    set gvars(n,reqdbls) 2;
    set gvars(s,reqdbls) 2;
    set gvars(e,reqdbls) 2;
    set gvars(w,reqdbls) 2;

    if {[string first "ai" $gvars(n,name)] == 0} {
	set gvars(n,reqdbls 0);
    }
    if {[string first "ai" $gvars(s,name)] == 0} {
	set gvars(s,reqdbls 0);
    }
    if {[string first "ai" $gvars(e,name)] == 0} {
	set gvars(e,reqdbls 0);
    }
    if {[string first "ai" $gvars(w,name)] == 0} {
	set gvars(w,reqdbls 0);
    }
}

proc ClearGameList {} {
    global gvars; 

    set gvars(games_remaining) [list 0 1 2 3 4 5 6 7 8 9];
}

proc ClearDblMatrix {} {
    global gvars;
    global dblmatrix;

    foreach pos1 {n e s w} {
	foreach pos2 {n e s w} {
	    set dblmatrix($pos1,$pos2) 0;
	}
    }
}

proc GetGameList {} {
    global gvars;

    set res "";

    for {set i 0} {$i < [llength $gvars(games_remaining)]} {incr i} {
	switch [lindex $gvars(games_remaining) $i] {
	    0 { lappend res [list Dominoes 0]}
	    1 { lappend res [list Queens 1]}
	    2 { lappend res [list "LastTwo" 2]}
	    3 { lappend res [list "KingOfHearts" 3]}
	    4 { lappend res [list "Hearts" 4]}
	    5 { lappend res [list "Tricks" 5]}
	    6 { lappend res [list "Trumps - Spades" 6]}
	    7 { lappend res [list "Trumps - Hearts" 7]}
	    8 { lappend res [list "Trumps - Diamonds" 8]}
	    9 { lappend res [list "Trumps - Clubs" 9]}
	}
    }
    return $res;
}

proc MarkGame {gvalue} {
    global gvars;

    if {$gvalue >= 6} {
	for {set gvalue 6} {$gvalue <= 9} {incr gvalue} {
	    set idx [lsearch $gvars(games_remaining) $gvalue];
	    if {$idx != -1} {
		set gvars(games_remaining) [lreplace $gvars(games_remaining) $idx $idx]
	    }
	}
    } else {
	set idx [lsearch $gvars(games_remaining) $gvalue];
	if {$idx != -1} {
	    set gvars(games_remaining) [lreplace $gvars(games_remaining) $idx $idx]
	}
    }
}

proc GetGameName {gvalue} {
    switch $gvalue {
	0 {return Dominoes}
	1 {return Queens}
	2 {return "LastTwo"}
	3 {return "KingOfHearts"}
	4 {return "Hearts"}
	5 {return "Tricks"}
	6 -
	7 -
	8 -
	9 {return "Trumps"}
    }
}

proc GetGameMsg {gvalue} {
    switch $gvalue {
	6 {return "with Spades"}
	7 {return "with Hearts"}
	8 {return "with Diamonds"}
	9 {return "with Clubs"}
	default {return ""}
    }
}

proc GetDblList {pos} {
    global gvars;
    global dblmatrix;

    set res "";
    foreach other {n e s w} {
	set skip 0;

	if {$other != $gvars(cur_dealer)} {
	    if {$gvars(cur_game) == 0} {
		set skip 1;
	    }
	    if {$gvars(cur_game) >= 6} {
		set skip 1;
	    }
	}

	if {!$skip} {
	    if {$other != $pos} {
		set curfactor $dblmatrix($other,$pos);
		set name $gvars($other,name);
		
		if {$other == $gvars(cur_dealer)} {
		    if {[NumGamesLeft] < $gvars($pos,reqdbls)} {
			set forced 1;
		    } else {
			set forced 0;
		    }
		} else {
		    set forced 0;
		}

		lappend res [list $name $curfactor $forced];
	    }
	}
    }
    return $res;
}

proc AfterMe {they me dealer} {
    switch $dealer {
	n {set dealer 0}
	e {set dealer 1}
	s {set dealer 2}
	w {set dealer 3}
    }
    switch $me {
	n {set me 0}
	e {set me 1}
	s {set me 2}
	w {set me 3}
    }
    switch $they {
	n {set they 0}
	e {set they 1}
	s {set they 2}
	w {set they 3}
    }

    set me [expr $me - $dealer];
    set they [expr $they - $dealer];

    if {$me < 0} {
	incr me 4;
    }
    if {$they < 0} {
	incr they 4;
    }

    if {$they > $me} {
	return 1;
    }
    return 0;
}

proc GetReDblList {pos} {
    global gvars;
    global dblmatrix;

    set res "";

    foreach other {n e s w} {
	if {$other != $pos} {
	    set they2me $dblmatrix($other,$pos);
	    set me2they $dblmatrix($pos,$other);

	    if {$they2me == 1} {
		if {$me2they == 0} {
		    if {[AfterMe $other $pos $gvars(cur_dealer)]} {
			set name $gvars($other,name);
			lappend res [list $name 1 0];
		    }
		}
	    }
	}
    }
    return $res;
}

proc ReflectDblMatrix {} {
    global dblmatrix;

    foreach p1 {n e s w} {
	foreach p2 {n e s w} {
	    if {$p1 != $p2} {
		if {$dblmatrix($p1,$p2) > $dblmatrix($p2,$p1)} {
		    set dblmatrix($p2,$p1) $dblmatrix($p1,$p2);
		} else {
		    set dblmatrix($p1,$p2) $dblmatrix($p2,$p1);
		}
	    }
	}
    }
}

proc MarkDbl {n1 n2 value} {
    global dblmatrix;
    global gvars;

    set p1 [MapNameToSeat $n1];
    set p2 [MapNameToSeat $n2];

    set dblmatrix($p1,$p2) $value;

    if {$p2 == $gvars(cur_dealer)} {
	if {$value == 1} {
	    if {$gvars($p1,reqdbls) > 0} {
		incr gvars($p1,reqdbls) -1;
	    }
	}
    }
}

proc NumGamesLeft {} {
    global gvars;

    set num_left [llength $gvars(games_remaining)];

    if {[lsearch $gvars(games_remaining) 6] != -1} {
	incr num_left -3;
    }

    return $num_left;
}

proc AdvancePlayer {pos} {
    global gvars;

    set name $gvars($pos,name);

    Broadcast "SetPlayTurn $name";

    if {$gvars(cur_game) != 0} {
	dp_RDO $gvars($pos,chann) EvalPlayableCards $gvars($gvars(cur_lead),cur_card);
    } else {
	dp_RDO $gvars($pos,chann) EvalPlayableCards {};
    }
}

proc CollectTrick {} {
    global gvars;

    #Determine who won.

    set leadsuit [GetLeadSuit];
    set trumpsuit [GetTrumpSuit];

    set high_lead [GetHighLead $leadsuit];
    set high_trump [GetHighTrump $trumpsuit];

    if {$high_trump > -1} {
	set winner [MapCardToPosition $high_trump];
    } else {
	set winner [MapCardToPosition $high_lead];
    }
    
    set game_over 0

    #Score any points.

    incr gvars($winner,ntricks);

    Broadcast "SetMsgOne $gvars($winner,name) \"$gvars($winner,ntricks) tricks\"";

    switch $gvars(cur_game) {
	1 {
	    set num_qs [GetNumQueens];
	    incr gvars($winner,score) [expr -6 * $num_qs];
	    incr gvars(queensout) $num_qs;
	    if {$gvars(queensout) == 4} {
		set game_over 1;
	    }
	}
	2 {
	    if {$gvars(num_tricks_played) == 11} {
		incr gvars($winner,score) -10;
	    } elseif {$gvars(num_tricks_played) == 12} {
		incr gvars($winner,score) -20;
	    }
	}
	3 {
	    if {[IsKofHThere]} {
		incr gvars($winner,score) -20;
		set game_over 1;
	    }
	}
	4 {
	    set num_hs [GetNumHearts];
	    incr gvars($winner,score) [expr -2 * $num_hs];
	    incr gvars(hrtsout) $num_hs;
	    if {$gvars(hrtsout) == 15} {
		set game_over 1;
	    }
	}
	5 {
	    incr gvars($winner,score) -2;
	}
	6 -
	7 -
	8 -
	9 {
	    incr gvars($winner,score) 5;
	}
    }
    
    #Move current hand to last card played

    foreach pos {n e s w} {
	if {$pos == $gvars(cur_lead)} {
	    Broadcast "SetLastCard $gvars($pos,name) $gvars($pos,cur_card) 1";
	} else {
	    Broadcast "SetLastCard $gvars($pos,name) $gvars($pos,cur_card) 0";
	}
    }

    #Clear table.

    Broadcast ClearTable;

    #Determine if game is over, if so, call DoEndGame
    
    incr gvars(num_tricks_played);

    if {$gvars(num_tricks_played) == 13} {
	set game_over 1;
    }

    if {!$game_over} {
	if {[AutoClaimTrue $winner]} {
	    # New leader will win rest of tricks;

	    # Broadcast what happened;

	    Broadcast "PostChatMsg system {$gvars($winner,name) will win rest of tricks.}";

	    # Score remaining points;

	    switch $gvars(cur_game) {
		1 {
		    set num_qs [expr 4 - $gvars(queensout)];
		    incr gvars($winner,score) [expr -6 * $num_qs];
		}
		2 {
		    if {$gvars(num_tricks_played) <= 11} {
			incr gvars($winner,score) -30;
		    } elseif {$gvars(num_tricks_played) == 12} {
			incr gvars($winner,score) -20;
		    }
		}
		3 {
		    incr gvars($winner,score) -20;
		}
		4 {
		    set num_hs [expr 15 - $gvars(hrtsout)];
		    incr gvars($winner,score) [expr -2 * $num_hs];
		}
		5 {
		    set num_ts [expr 13 - $gvars(num_tricks_played)];
		    incr gvars($winner,score) [expr -2 * $num_ts];
		}
	    }
	    set game_over 1;
	}
    }
		    
    if {$game_over} {
	DoEndGame;
    } else {
	#Otherwise start new led.
	
	set gvars(n,cur_card) "";
	set gvars(e,cur_card) "";
	set gvars(s,cur_card) "";
	set gvars(w,cur_card) "";
	set gvars(cur_lead) $winner;
	set gvars(cur_trick,num_played) 0;

	AdvancePlayer $winner;
    }
}

proc DoEndGame {} {
    global gvars dblmatrix

    Broadcast "SetPlayMode 0";
    Broadcast "SetGMsg {Game is completed.}";

    # Calculate scores with doubles.

    set tmpscore(n) 0;
    set tmpscore(e) 0;
    set tmpscore(s) 0;
    set tmpscore(w) 0;

    foreach p1 {n e s w} {
	incr tmpscore($p1) $gvars($p1,score);
	foreach p2 {n e s w} {
	    if {$p1 != $p2} {
		incr tmpscore($p1) [expr $dblmatrix($p1,$p2) * ($gvars($p1,score) - $gvars($p2,score))];
	    }
	}
    }

    # Post scores.

    Broadcast "PostScore $gvars(cur_dealer) n [GetGameAbbrev] $tmpscore(n)";
    Broadcast "PostScore $gvars(cur_dealer) s [GetGameAbbrev] $tmpscore(s)";
    Broadcast "PostScore $gvars(cur_dealer) e [GetGameAbbrev] $tmpscore(e)";
    Broadcast "PostScore $gvars(cur_dealer) w [GetGameAbbrev] $tmpscore(w)";

    # If games left for this dealer, start new game

    if {[NumGamesLeft] > 0} {
	StartPlay
	return;
    }

    # If not, if not last dealer, start new dealer.

    switch $gvars(cur_dealer) {
	n {
	    SetupDealer e;
	    StartPlay
	}
	e {
	    SetupDealer s;
	    StartPlay
	}
	s {
	    SetupDealer w;
	    StartPlay
	}
	w {
	    Broadcast "SetGMsg {Barbu is complete!}";
	}
    }
}

proc GetGameAbbrev {} {
    global gvars;

    switch $gvars(cur_game) {
	0 {return d}
	1 {return q}
	2 {return lt}
	3 {return kh}
	4 {return h}
	5 {return t}
	6 -
	7 -
	8 -
	9 {return tr}
    }
}
	    

proc MapNameToSeat {name} {
    global gvars;

    switch $name \
	    $gvars(n,name) {return n} \
	    $gvars(s,name) {return s} \
	    $gvars(e,name) {return e} \
	    $gvars(w,name) {return w}
}

proc ConstructDblMsg {name dlist} {
    global gvars;

    set dbls "";
    set redbls "";

    foreach entry $dlist {
	set dname [lindex $entry 0];
	set dvalue [lindex $entry 1];
    
	if {$dvalue == 1} {
	    lappend dbls $dname;
	} elseif {$dvalue == 2} {
	    lappend redbls $dname;
	}
    }

    set no_doubles 0;

    switch [llength $dbls] {
	0 {
	    set no_doubles 1;
	}
	1 {
	    set res "$name doubles $dbls";
	} 
	2 {
	    set res "$name doubles [lindex $dbls 0] and [lindex $dbls 1]";
	}
	3 {
	    set res "$name doubles everyone";
	}
    }

    switch [llength $redbls] {
	0 {
	    if {$no_doubles} {
		set res "$name passes.";
	    } else {
		set res "${res}.";
	    }
	}
	1 {
	    if {$no_doubles} {
		set res "$name redoubles $redbls.";
	    } else {
		set res "${res}; redoubles $redbls.";
	    }
	}
	2 {
	    if {$no_doubles} {
		set res "$name redoubles [lindex $redbls 0] and [lindex $redbls 1].";
	    } else {
		set res "${res}; redoubles [lindex $redbls 0] and [lindex $redbls 1].";
	    }
	} 
	3 {
	    set res "$name redoubles everyone.";
	}
    }

    return $res;
}

proc GetLeadSuit {} {
    global gvars;

    set ldr $gvars(cur_lead);

    set cnum $gvars($ldr,cur_card);

    return [expr $cnum / 13];
}

proc GetTrumpSuit {} {
    global gvars;

    switch $gvars(cur_game) {
	6 {return 0}
	7 {return 1}
	8 {return 2}
	9 {return 3}
	default {return ""}
    }
}

proc GetHighLead {lsuit} {
    global gvars;

    set cur_high -1;

    foreach cnum "$gvars(n,cur_card) $gvars(s,cur_card) $gvars(e,cur_card) $gvars(w,cur_card)" {
	set suit [expr $cnum / 13];

	if {$suit == $lsuit} {
	    if {$cnum > $cur_high} {
		set cur_high $cnum;
	    }
	}
    }

    return $cur_high;
}

proc GetHighTrump {tsuit} {

    if {$tsuit == ""} {
	return -1;
    }

    return [GetHighLead $tsuit];
}

proc MapCardToPosition {cnum} {
    global gvars;

    switch $cnum \
	    $gvars(n,cur_card) {return n} \
	    $gvars(s,cur_card) {return s} \
	    $gvars(e,cur_card) {return e} \
	    $gvars(w,cur_card) {return w} 
}

proc GetNumQueens {} {
    global gvars;

    set cnt 0;

    foreach cnum "$gvars(n,cur_card) $gvars(s,cur_card) $gvars(e,cur_card) $gvars(w,cur_card)" {
	if {[expr $cnum % 13] == 10} {
	    incr cnt;
	}
    }

    return $cnt;
}

proc IsKofHThere {} {
    global gvars;

    foreach cnum "$gvars(n,cur_card) $gvars(s,cur_card) $gvars(e,cur_card) $gvars(w,cur_card)" {
	if {$cnum == 24} {
	    return 1;
	}
    }
    return 0;
}

proc GetNumHearts {} {
    global gvars;

    set cnt 0;

    foreach cnum "$gvars(n,cur_card) $gvars(s,cur_card) $gvars(e,cur_card) $gvars(w,cur_card)" {
	if {[expr $cnum / 13] == 1} {
	    if {[expr $cnum % 13] == 12} {
		incr cnt 3;
	    } else {
		incr cnt;
	    }
	}
    }

    return $cnt;
}

proc ReportChatMsg {name msg} {
    Broadcast "PostChatMsg {$name} {$msg}";
}

proc AutoClaimTrue {winner} {
    global gvars;

    switch $gvars(cur_game) {
	0 -
	6 -
	7 -
	8 -
	9 {
	    return 0;
	}
    }
	
    foreach pos {n e s w} {
	foreach suit {s h d c} {
	    set tmp($pos,$suit,lo) 13;
	    set tmp($pos,$suit,hi) -1;
	}
    }

    foreach pos {n e s w} {
	foreach cnum $gvars($pos,hand) {
	    set suit [expr $cnum / 13];
	    set rank [expr $cnum % 13];

	    switch $suit 0 {set suit s} 1 {set suit h} 2 {set suit d} 3 {set suit c}
	    if {$tmp($pos,$suit,lo) > $rank} {
		set tmp($pos,$suit,lo) $rank;
	    }
	    if {$tmp($pos,$suit,hi) < $rank} {
		set tmp($pos,$suit,hi) $rank;
	    }
	}
    }

    switch $winner {
	n {set others "e s w"}
	e {set others "n s w"}
	s {set others "n e w"}
	w {set others "n e s"}
    }

    foreach pos $others {
	foreach suit {s h d c} {
	    if {$tmp($pos,$suit,hi) > $tmp($winner,$suit,lo)} {
		return 0;
	    }
	}
    }
    return 1;
}

proc DoCommunication {pos cmd} {
    global gvars;

    if {[catch "eval dp_RDO $gvars($pos,chann) $cmd"]} {
	lappend gvars($pos,comm_queue) $cmd;
    }
}

proc DoReconnect {name} {
    global gvars;
    global dp_rpcFile;

    switch $name \
	    $gvars(n,name) {set pos n} \
	    $gvars(e,name) {set pos e} \
	    $gvars(s,name) {set pos s} \
	    $gvars(w,name) {set pos w}

    # Set back channel.

    set gvars($pos,chann) $dp_rpcFile;

    # Do GameBoard, ScoreBoard, Chat Init's here.

    switch $pos {
	n {
	    DoCommunication $pos "InitGameBoard $gvars(n,name) $gvars(e,name) $gvars(s,name) $gvars(w,name)";
	}
	e {
	    DoCommunication $pos "InitGameBoard $gvars(e,name) $gvars(s,name) $gvars(w,name) $gvars(n,name)";
	}
	s {
	    DoCommunication $pos "InitGameBoard $gvars(s,name) $gvars(w,name) $gvars(n,name) $gvars(e,name)";
	}
	w {
	    DoCommunication $pos "InitGameBoard $gvars(w,name) $gvars(n,name) $gvars(e,name) $gvars(s,name)";
	}
    }

    DoCommunication $pos "InitScoreboard $gvars(n,name) $gvars(e,name) $gvars(s,name) $gvars(w,name)";

    DoCommunication $pos InitChat

    DoCommunication $pos "SetDealer $gvars($gvars(cur_dealer),name)";

    # Set Game with packing.

    if {$gvars(cur_game) != 0} {
	set gname [GetGameName $gvars(cur_game)];
	set gmsg [GetGameMsg $gvars(cur_game)];
	
	if {$gvars(cur_game) >= 6} {
	    switch $gvars(cur_game) {
		6 {DoCommunication $pos {SetTrump 0}};
		7 {DoCommunication $pos {SetTrump 1}};
		8 {DoCommunication $pos {SetTrump 2}};
		9 {DoCommunication $pos {SetTrump 3}};
	    }
	}

	DoCommunication $pos "SetGame \"$gname\" \"$gmsg\"";
	
	DoCommunication $pos PackForTricks;
    } else {
	set gname [GetGameName 0];
	set gmsg "from the $gvars(dominoes_start).";

	DoCommunication $pos "InitDominoes $gvars(dominoes_start)";
	DoCommunication $pos PackForDominoes;

	DoCommunication $pos "SetGame $gname \"$gmsg\"";
    }

    # Transmit hand.
    
    DoCommunication $pos "SetHand {$gvars($pos,hand)}";

    # Post play of other players.

    if {$gvars(n,cur_card) != ""} {
	DoCommunication $pos "PostPlay $gvars(n,name) $gvars(n,cur_card)";
    } 
    if {$gvars(e,cur_card) != ""} {
	DoCommunication $pos "PostPlay $gvars(e,name) $gvars(e,cur_card)";
    } 
    if {$gvars(s,cur_card) != ""} {
	DoCommunication $pos "PostPlay $gvars(s,name) $gvars(s,cur_card)";
    } 
    if {$gvars(w,cur_card) != ""} {
	DoCommunication $pos "PostPlay $gvars(w,name) $gvars(w,cur_card)";
    } 

    # Send outstanding communications.
	
    foreach cmd $gvars(pos,comm_queue) {
	eval dp_RDO $gvars($pos,chann) $cmd;
    }
    set gvars(pos,comm_queue) "";
}


proc PrintNames {} {
global gvars;

puts "$gvars(n,name) $gvars(s,name) $gvars(e,name) $gvars(w,name)"
}

#===========================================================================
# DpTcl.tpl -- (BS)
#
#       Implements a tclDP compatible portable RPC library atop of the 
#       Tcl 7.5 socket command.
#
# Copyright (c) 1996 Eolas Technologies, Inc.
# Copyright (c) 1996 Computerized Processes Unlimited, Inc.
# Copyright (c) 1996 Mark Roseman
# Copyright (c) 1996 Brian Smith
# all rights reserved.
#
# The authors hereby grant permission to use, copy, modify, distribute,
# and license this software and its documentation for any purpose, provided
# that existing copyright notices are retained in all copies and that this
# notice is included verbatim in any distributions. No written agreement,
# license, or royalty fee is required for any of the authorized uses.
# Modifications to this software may be copyrighted by their authors
# and need not follow the licensing terms described here, provided that
# the new terms are clearly indicated on the first page of each file where
# they apply.
# 
# IN NO EVENT SHALL THE AUTHORS OR DISTRIBUTORS BE LIABLE TO ANY PARTY
# FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
# ARISING OUT OF THE USE OF THIS SOFTWARE, ITS DOCUMENTATION, OR ANY
# DERIVATIVES THEREOF, EVEN IF THE AUTHORS HAVE BEEN ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# 
# THE AUTHORS AND DISTRIBUTORS SPECIFICALLY DISCLAIM ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.  THIS SOFTWARE
# IS PROVIDED ON AN "AS IS" BASIS, AND THE AUTHORS AND DISTRIBUTORS HAVE
# NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
# MODIFICATIONS.
# 
# RESTRICTED RIGHTS: Use, duplication or disclosure by the government
# is subject to the restrictions as set forth in subparagraph (c) (1) (ii)
# of the Rights in Technical Data and Computer Software Clause as DFARS
# 252.227-7013 and FAR 52.227-19.
# 
#
#---------------------------------------------------------------------------

# -- validate appropriate execution environment
if {[catch {info tclversion} tclversion] || $tclversion < 7.5} {
    return -code error "DpTcl requires Tcl7.5 / Tk4.1 or later releases"
} else {unset tclversion}

package provide Dp 3.5

#----------
# -- create a client RPC connection
proc dp_MakeRPCClient {host port {checkProc ""}} {
    global _rpc
    if {[catch {socket $host $port} sock]} {
        return -code error "dp_MakeRPCClient:  $sock"
    }
    set _rpc($sock,state) idle
    set _rpc($sock,RPCdisabled) 0
    set _rpc($sock,closehooks) ""
    set _rpc($sock,checkhook) $checkProc
    set _rpc($sock,safeinterp) [interp create -safe];
    interp eval $_rpc($sock,safeinterp) {proc unknown {cmd args} { \
	    return [eval _myrpc_checkhandler $cmd $args];}};
    interp alias $_rpc($sock,safeinterp) _myrpc_checkhandler {} _myrpc_checkhandler $sock;
    interp eval $_rpc($sock,safeinterp) {rename proc ""};

    set _rpc($sock,isClient) 1
    set _rpc($sock,isServer) 0
    dp_atexit prepend close $sock
    catch {fconfigure $sock -blocking 0 -buffering none}
    catch {fileevent $sock readable [list _myrpc_readable $sock]}
    return $sock
}

#----------
# -- create an RPC server and make it available for client connections
proc dp_MakeRPCServer {{port 0} {logincmd ""} {checkcmd ""} {closecmd ""}} {
    global _rpc
    if {[catch {socket -server [list _myrpc_accept $port] $port} sock]} {
        return -code error "dp_MakeRPCServer:  $sock"
    }
    if {$checkcmd == "none"} {
        set checkcmd ""
    }
    if {$closecmd == "none"} {
        set closecmd ""
    }
    if {$logincmd == "none"} {
	set logincmd "";
    }
    
    set _rpc(listen$port,checkhook) $checkcmd
    set _rpc(listen$port,closehook) $closecmd
    set _rpc(listen$port,loginhook) $logincmd

    if {$port == 0} {
        set port [lindex [fconfigure $sock -sockname] 2]
    }
    # -- if no access control list set, let everyone in
    return $port
}

#----------
# -- send an asynchronous RPC Tcl command (don't wait for result)
proc dp_RDO {sock args} {
    set ceTemplate {
       if [catch {%s} dp_rv] {
            dp_RDO $dp_rpcFile set errorInfo "$errorInfo\n\twhile remotely executing\n%s"
            dp_RDO $dp_rpcFile eval "%s {$dp_rv}"
        } else {
            dp_RDO $dp_rpcFile eval "%s {$dp_rv}"
        }
    }

    set eTemplate {
        if [catch {%s} dp_rv] {
            dp_RDO $dp_rpcFile set errorInfo "$errorInfo\n\twhile remotely executing\n%s"
            dp_RDO $dp_rpcFile eval "%s {$dp_rv}"
        }
    }

    set cTemplate {
        set dp_rv [%s]; 
        dp_RDO $dp_rpcFile eval "%s {$dp_rv}"
    }

    set onerrorPresent [lsearch -exact $args -onerror]
    if {$onerrorPresent == -1} {
        set onerrorPresent 0
    } else {
        set onerror [lindex $args [expr {$onerrorPresent + 1}]]
        set args [concat \
            [lrange $args 0 [expr {$onerrorPresent - 1}]] \
            [lrange $args [expr {$onerrorPresent + 2}] end] \
        ]
        set onerrorPresent 1
    }

    set callbackPresent [lsearch -exact $args -callback]
    if {$callbackPresent == -1} {
        set callbackPresent 0
    } else {
        set callback [lindex $args [expr {$callbackPresent + 1}]]
        set args [concat \
            [lrange $args 0 [expr {$callbackPresent - 1}]] \
            [lrange $args [expr {$callbackPresent + 2}] end] \
        ]
        set callbackPresent 1
    }

    if {$onerrorPresent && $callbackPresent} {
	# Both onerror & callback specified.
	set command [format $ceTemplate $args $args $onerror $callback]
    } elseif {$onerrorPresent} {
	# Onerror specififed
	set command [format $eTemplate $args $args $onerror]
    } elseif {$callbackPresent} {
	# Just callback specified.
	set command [format $cTemplate $args $callback]
    } else {
	# No callbacks specified. 
	set command $args
    }
    
    if {[catch {eof $sock} eofflag] || $eofflag} {
        return -code error "dp_RDO:  socket $sock is not open"
    }
    catch {fconfigure $sock -blocking 1 -buffering full}
    catch {puts -nonewline $sock [format {%6d} [string length $command]]}
    catch {puts -nonewline $sock "d \{$command\}"}
    if {[catch {flush $sock}]} {
	catch {fileevent $sock readable {}}
	catch {close $sock}
	return
    }
    catch {fconfigure $sock -blocking 0 -buffering none}
    return {}
}

#----------
# -- send a Tcl command to remote server, retrieve result of remote execution
proc dp_RPC {sock args} {
    global _rpc
    if {[catch {eof $sock} eofflag] || $eofflag} {
	catch {fileevent $sock readable {}}
	catch {close $sock}
        return -code error "dp_RPC:  socket $sock is not open"
    }
    catch {fconfigure $sock -blocking 1 -buffering full}
    catch {puts -nonewline $sock [format {%6d} [string length $args]]}
    catch {puts -nonewline $sock "e \{$args\}"}
    if {[catch {flush $sock}]} {
	catch {fileevent $sock readable {}}
	catch {close $sock}
        return {}
    }
    if {[catch {eof $sock} eofflag] || $eofflag} {
        return -code error "dp_RPC:  socket $sock is not open"
    }
    set _rpc($sock,RPCdisabled) 1
    while {[string compare $_rpc($sock,state) answered]} {
        catch {fconfigure $sock -blocking 1 -buffering full}
        _myrpc_readable $sock
    }
    catch {fconfigure $sock -blocking 0 -buffering none}
    set _rpc($sock,RPCdisabled) 0
    set _rpc($sock,state) idle
    if {[string compare $_rpc($sock,type) r]} {
        ##
        ## Type must be x, for error,
        ##
        foreach {results info code} $_rpc($sock,buffer) {break}
        return -code error -errorinfo $info -errorcode $code $results
    } else {
        ##
        ## Type must be r, for results,
        ##
        return $_rpc($sock,buffer)
    }
}

#----------
# -- cleanly close an RPC_connection on both sides from the client
proc dp_CloseRPC {sock} {
	catch {fileevent $sock readable {}}
	catch {close $sock}
}

#----------
# -- client cancels pending RPC operations at server end
proc dp_Cancel {args} {
    # -- no-op, for now
}

#----------
# -- set a command to check incoming Tcl command requests of the server
proc dp_SetCheckCmd {sock args} {
    global _rpc
    if {[catch {eof $sock} eofflag] || $eofflag} {
	catch {fileevent $sock readable {}}
	catch {close $sock}
        return -code error "dp_SetCheckCmd:  socket $sock is not open"
    }
    set _rpc($sock,checkhook) $args
}

#----------
# -- server function to maintain access control list
proc dp_Host {host} {
    global _rpc
    # -- validate host argument as being well formed IP address
    set opcode [string index $host 0]
    if {$opcode != "+" && $opcode != "-"} {
        return -code error "dp_Host usage: dp_Host \[+\|-\]ipaddress"
    }
    if {[string length $host] == 1} {
        append host "*.*.*.*"
    }
    set iplist [string range $host 1 [expr [string length $host] - 1]]
    set iplist [split $iplist "."]
    if {[llength $iplist] != 4} {
        # -- assume non-ip hostname given...can't handle it so return
        return {}
    }
    foreach ipitem $iplist {
        if {$ipitem != "*"} {
            if {[catch {expr $ipitem * 1}] || $ipitem > 255} {
                # -- assume non-ip hostname given,..can't handle so return
                return {}
            }
        }
    }
    # -- create the acl list, enable universal access, add modifier 
    if {![info exists _rpc(acl)]} {
        lappend _rpc(acl) [list + * * * *]
    }
    lappend _rpc(acl) "$opcode $iplist"
    return {}
}

#----------
# -- define commands to be executed just prior to really exiting
proc dp_atexit {option args} {
    global _rpc
    if {![info exists _rpc(atexit)]} {
        # -- create exit callbacks, replace exit command to invoke them
        rename exit dp_atexit_really_exit
        set _rpc(atexit) ""
        uplevel #0 {proc exit {{code 0}} {
            global _rpc
            while {1} {
                if {[catch {set _rpc(atexit)} _rpc(atexit)]} {
                    break
                }
                if {[llength $_rpc(atexit)] <= 0} {
                    break
                }
                set callback [lindex $_rpc(atexit) 0]
                set _rpc(atexit) [lrange $_rpc(atexit) 1 end]
                catch {uplevel #0 "$callback"}
            }
            catch {unset _rpc(atexit)}
            catch {dp_atexit_really_exit $code}
        }   
        }
    }
    switch -exact -- $option {
        set {
            set _rpc(atexit) [split $args]
        }
        appendUnique {
            lappend _rpc(atexit) $args
        }
        append {
            lappend _rpc(atexit) $args
        }
        prepend {
            set _rpc(atexit) [linsert $_rpc(atexit) 0 $args] 
        }
        insert {
            set _rpc(atexit) [linsert $_rpc(atexit) 0 $args
        }
        delete {}
        clear {
            set _rpc(atexit) ""
        }
        list {
            return $_rpc(atexit)
        }
        default {
            return -code error "dp_atexit: unrecognized option \[$option\]"
	}
    }
    return $_rpc(atexit)
}

#----------
# -- register callbacks to RPC channel to execute just before channel closes
proc dp_atclose {sock option args} {
    global _rpc
    if {![info exists _rpc($sock,isClient)]} {
        return
    }
    if {[catch {eof $sock} eofflag] || $eofflag} {
	catch {fileevent $sock readable {}}
	catch {close $sock}
        return -code error "dp_atclose:  socket $sock is not open"
    }
    switch -exact -- $option {
        set {
            set _rpc($sock,closehooks) $args
        }
        append {
            lappend _rpc($sock,closehooks) $args
        }
        appendUnique {
            lappend _rpc($sock,closehooks) $args
        }
        prepend {
            set _rpc($sock,closehooks) [linsert $_rpc($sock,closehooks) 0 $args] 
        }
        insert {
            set _rpc($sock,closehooks) [linsert $_rpc($sock,closehooks) 0 $args] 
        }
        delete {}
        clear {
            set _rpc($sock,closehooks) ""
        }
        list {
            return $_rpc($sock,closehooks)
        }
        default {
            return -code error "dp_atclose: unrecognized option \[$option\]"
        }
    }
    return $_rpc($sock,closehooks)
}

# -- replacement close function to ensure RPC close callbacks are run
if {![llength [info commands dp_atclose_really_close]]} {
    rename close dp_atclose_really_close
    proc close {sock} {
        global _rpc
        if {"" == [array names _rpc $sock,*]} {
            dp_atclose_really_close $sock
            return {}
        }
        if {![info exists _rpc($sock,isServer)]} {
            dp_atclose_really_close $sock
            return {}
        }
        if {$_rpc($sock,isClient)} {
            catch {dp_RDO $sock close [dp_RPC $sock set dp_rpcFile]}
        }
        fileevent $sock readable ""
        foreach i $_rpc($sock,closehooks) {
            catch {uplevel #0 $i}
        }
        dp_atclose_really_close $sock
        after 10 _myrpc_remove_client $sock
    }
}    
    
#----------
# -- return RPC channel identifier
proc rpcFile {} {
    global myrpc_channel
    if {[info exists myrpc_channel]} {
        return $myrpc_channel
    } else {
        return {}
    }
}

#----------
# -- INTERNAL:  Server accepts a client connection
proc _myrpc_accept {listener sock addr port} {
    global _rpc

    if {[info exists _rpc(acl)] && [llength $_rpc(acl)] > 1} {
        set cip [split $addr "."]
        set allowed 1
        foreach ip $_rpc(acl) {
            set opcode [lindex $ip 0]
            set ip [lrange $ip 1 4]
            set j 0
            for {set i 0} {$i<4} {incr i} {
                if {[lindex $ip $i] == "*" || \
                        [lindex $ip $i] == [lindex $cip $i]} {
                    incr j
                }
            }
            if {$j == 4} {
                if {$opcode == "-"} {
                    set allowed 0
                } else {
                    set allowed 1
                }
            }
        }
        if {!$allowed} {
            puts stderr "RPC connection from $addr refused"
		catch {fileevent $sock readable {}}
		catch {close $sock}
            return
        }
    }
    if {$_rpc(listen$listener,loginhook) != ""} {
	if {[catch "$_rpc(listen$listener,loginhook) $addr"]} {
	    puts stderr "RPC connection from $addr refused"
	    catch {fileevent $sock readable {}}
	    catch {close $sock}
	    return;
	}
    }

    set _rpc($sock,state) idle
    set _rpc($sock,closehooks) $_rpc(listen$listener,closehook)
    set _rpc($sock,checkhook) $_rpc(listen$listener,checkhook)
    set _rpc($sock,safeinterp) [interp create -safe];
    interp eval $_rpc($sock,safeinterp) {proc unknown {cmd args} { \
	    return [eval _myrpc_checkhandler $cmd $args];}};
    interp alias $_rpc($sock,safeinterp) _myrpc_checkhandler {} _myrpc_checkhandler $sock;
    interp eval $_rpc($sock,safeinterp) {rename proc ""};

    set _rpc($sock,listener) $listener
    set _rpc($sock,clientip) $addr
    set _rpc($sock,ipport) $port
    set _rpc($sock,RPCdisabled) 0
    set _rpc($sock,isClient) 0
    set _rpc($sock,isServer) 1
    dp_atexit prepend close $sock
    if {[eof $sock]} {
	catch {fileevent $sock readable {}}
	catch {close $sock}
        return -code error "dp_MakeRPCServer:  socket $sock is not open"
    }
    catch {fconfigure $sock -blocking no -buffering none}
    catch {fileevent $sock readable [list _myrpc_readable $sock]}
}

#----------
# -- INTERNAL:  Client or Server interupt processing for new data on the
#               RPC channel
proc _myrpc_readable {sock} {
    global _rpc

    if {[catch {eof $sock} eofflag] || $eofflag} {
	catch {fileevent $sock readable {}}
	catch {close $sock}
        return
    }
    switch $_rpc($sock,state) {
        idle {
            set _rpc($sock,state) readhdr
            set _rpc($sock,buffer) ""
            set _rpc($sock,toread) 6
            _myrpc_readhdr $sock
        }
        readhdr {
            _myrpc_readhdr $sock
        }
        readmsg {
            _myrpc_readmsg $sock
        }
    }
}

#----------
# -- INTERNAL:  read metadata component of message received over RPC channel
proc _myrpc_readhdr {sock} {
    global _rpc
    if {[catch {eof $sock} eofflag] || $eofflag} {
	catch {fileevent $sock readable {}}
	catch {close $sock}
        return
    }
    if {[catch {read $sock $_rpc($sock,toread)} result]} {
	catch {fileevent $sock readable {}}
	catch {close $sock}
        return
    }
    if {$result == ""} {
	catch {fileevent $sock readable {}}
	catch {close $sock}
        return
    }
    append _rpc($sock,buffer) $result
    incr _rpc($sock,toread) [expr -[string length $result]]
    if {$_rpc($sock,toread) == 0} {
        set _rpc($sock,state) readmsg
 	if {$_rpc($sock,isServer)} { 
            set _rpc($sock,toread) [expr $_rpc($sock,buffer) + 4] 
	}
        if {$_rpc($sock,isClient)} { 
            set _rpc($sock,toread) [expr $_rpc($sock,buffer) + 4] 
        }
	set _rpc($sock,buffer) ""
    }
    if {[catch {eof $sock} eofflag] || $eofflag} {
	catch {fileevent $sock readable {}}
	catch {close $sock}
        return
    }
}

#----------
# -- INTERNAL:  read/check/execute Tcl command/result component of message 
#               received over RPC channel
proc _myrpc_readmsg {sock} {
    global _rpc errorInfo errorCode
    global myrpc_channel dp_rpcFile 
    if {[catch {read $sock $_rpc($sock,toread)} result]} {
	catch {fileevent $sock readable {}}
	catch {close $sock}
        return
    }
    if {$result == ""} {
        # close $sock
        return
    }
    append _rpc($sock,buffer) $result
    incr _rpc($sock,toread) [expr -[string length $result]]
    if {$_rpc($sock,toread) == 0} {
        set dp_rpcFile $sock
        set myrpc_channel $sock
        set _rpc($sock,state) idle
        set _rpc($sock,type) [lindex $_rpc($sock,buffer) 0]
        switch -exact $_rpc($sock,type) {
            x {
                ##
                ## Error result return 
                ##
                set _rpc($sock,state) answered
                set _rpc($sock,buffer) [lrange $_rpc($sock,buffer) 1 end]
                return
            }
            r {
                ##
                ## Normal result return 
                ##
                set _rpc($sock,state) answered
                set _rpc($sock,buffer) [lindex $_rpc($sock,buffer) 1]
                return
            }
            e {
                ##
                ## Rpc call
                ##
                if {$_rpc($sock,RPCdisabled)} {
                    set blockingState [fconfigure $sock -blocking]
                    set bufferState [fconfigure $sock -buffering]
                    set _rpc($sock,outbuf) [list x {dp_RPC: deadlock detected, RPC aborted} {} {}]
                    set _rpc($sock,outlen) [string length _rpc($sock,outbuf)]
                    set hdr [format "%6d" [expr $_rpc($sock,outlen)-4]]
                    if {[catch {eof $sock} eofflag] || $eofflag} {
        		catch {fileevent $sock readable {}}
        		catch {close $sock}
                    }
                    catch {fconfigure $sock -blocking 1 -buffering full}
                    if {[catch {puts -nonewline $sock $hdr}]} {
			catch {fileevent $sock readable {}}
			catch {close $sock}
        	    }
                    if {[catch {flush $sock}]} {
			catch {fileevent $sock readable {}}
			catch {close $sock}
        	    }
                    _myrpc_writeresult $sock
                    catch {fconfigure $sock -blocking $blockingState -buffering $bufferState}
                    return                    
                }
            }
            d {
                ##
                ## Rdo call
                ##
            }
        }
        # -- if no checking proc or checking proc does not error out, eval
        # -- the command
        set status 1
        set _rpc($sock,outdone) 0
 	set cmd [lindex $_rpc($sock,buffer) 1]

	if {![string compare $_rpc($sock,type) d]} {
	    interp eval $_rpc($sock,safeinterp) " \
		    after 1 \{                              \
		    set myrpc_channel $myrpc_channel;       \
		    set dp_rpcFile $dp_rpcFile;             \
		    catch {$cmd};                           \
		    catch {unset myrpc_channel};            \
		    catch {unset dp_rpcFile};               \
		    \}"
	    return
	}

	if {[catch {interp eval $_rpc($sock,safeinterp) $cmd} result]} {
	    set _rpc($sock,outbuf) [list x $result $errorInfo $errorCode]
	} else {
	    set _rpc($sock,outbuf) [list r $result]
	}
	set _rpc($sock,outlen) [string length $_rpc($sock,outbuf)]

        if {![string compare $_rpc($sock,type) e]} {
            if {[catch {eof $sock} eofflag] || $eofflag} {
		catch {fileevent $sock readable {}}
		catch {close $sock}
		return
            }
            catch {fconfigure $sock -blocking 1 -buffering full}
            set hdr [format "%6d" [expr $_rpc($sock,outlen)-4]]
            if {[catch {puts -nonewline $sock $hdr}]} {
		catch {fileevent $sock readable {}}
		catch {close $sock}
		return
            }
            if {[catch {flush $sock}]} {
		catch {fileevent $sock readable {}}
		catch {close $sock}
		return
            }
            _myrpc_writeresult $sock
            catch {fconfigure $sock -blocking 0 -buffering none}
        }
        catch {unset myrpc_channel}
        catch {unset dp_rpcFile}
    }
}

#----------
# -- write result of command back to client based on writable event
proc _myrpc_writeresult {sock} {
    global _rpc
    while {!$_rpc($sock,outdone)} {
        if {$_rpc($sock,outlen) <= 0} {
            set _rpc($sock,outdone) 1
#            update idletasks
            return
        }
        if {$_rpc($sock,outlen) > 4096} {
            set len 4096
        } else {
            set len $_rpc($sock,outlen)
        }
        set packet "[string range $_rpc($sock,outbuf) 0 [expr $len - 1]]"
        set _rpc($sock,outbuf) "[string range $_rpc($sock,outbuf) $len [expr $_rpc($sock,outlen) - 1]]"
        incr _rpc($sock,outlen) -[set len]
        if {[catch {eof $sock} eofflag] || $eofflag} {
	    catch {fileevent $sock readable {}}
	    catch {close $sock}
            return
        }
        if {[catch {puts -nonewline $sock $packet}]} {
	    catch {fileevent $sock readable {}}
	    catch {close $sock}
            return
        }
        if {[catch {flush $sock}]} {
	    catch {fileevent $sock readable {}}
	    catch {close $sock}
            return
        }
        if {[catch {eof $sock} eofflag] || $eofflag} {
	    catch {fileevent $sock readable {}}
	    catch {close $sock}
            return
        }
#        update idletasks
    }
}

#----------
# -- get rid of a client's entry
proc _myrpc_remove_client {sock} {
    global _rpc
    foreach item [array names _rpc "$sock,*"] {
        catch {unset _rpc($item)}
    } 
}

proc _myrpc_checkhandler {sock cmd args} {
    global _rpc;

    if {$_rpc($sock,checkhook) == ""} {
	interp alias $_rpc($sock,safeinterp) $cmd {} $cmd;
	return [eval $cmd $args];
    } elseif {[$_rpc($sock,checkhook) $cmd] == 1} {
	interp alias $_rpc($sock,safeinterp) $cmd {} $cmd;
	return [eval $cmd $args];
    } else {
	error "The command $cmd is disallowed";
    }
}

#----------
# -- report background errors on the server
if {[info procs bgerror] == ""} {
    proc bgerror {args} {
        global errorInfo errorCode
        puts stderr "Background error: $args"
        puts stderr "\t$errorInfo"
        puts stderr "errorCode = \[$errorCode\]"
        return {}
    }
}

expr srand([clock clicks]);

proc Shuffle {} {

    # Initialize deck.

    for {set i 0} {$i < 52} {incr i} {
	set deck($i) $i;
    }

    # Transpose each position with random position ahead of it.

    for {set i 0} {$i < 51} {incr i} {
	set rpos_range [expr 52 - $i - 1];

	set rpos [expr (int(rand() * $rpos_range)) + 1 + $i];

	set tmp $deck($rpos);
	set deck($rpos) $deck($i);
	set deck($i) $tmp;
    }

    set res "";
    for {set i 0} {$i < 52} {incr i} {
    	lappend res $deck($i);
    }

    return $res;
}
    
set port 5757;

InitGameVariables;

dp_MakeRPCServer $port;


