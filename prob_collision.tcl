

proc prob_hit_slow {probOneHit  numItems} {
    set hit $probOneHit
    set miss [expr 1 - $probOneHit]

    set result $hit

    for {set i 2} {$i <= $numItems} {incr i} {
	set tmp $hit
	# runs for up to numItems - 1
	for {set j 1} {$j < $i} {incr j} {
	    set tmp [expr $tmp * $miss]
	}
	#puts "tmp : $tmp"
	set result [expr $result + $tmp]
	#puts "result [expr $result + $tmp]"
    }
    return $result
}

proc prob_hit {probOneHit  numItems} {
    set hit $probOneHit
    set miss [expr 1 - $probOneHit]

    set result $hit
    set prev $result

    for {set i 2} {$i <= $numItems} {incr i} {
	set prev [expr $prev * $miss]
	set result [expr $result + $prev]
	#puts "result [expr $result + $tmp]"
    }
    return $result
}

puts "prob_hit [lindex $argv 0] [lindex $argv 1]"
puts "[prob_hit [lindex $argv 0] [lindex $argv 1]]"
