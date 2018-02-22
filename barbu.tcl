
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


set autoplay 0;

proc InitGameBoard {myname left across right} {
    global gbvars;

    set myname [string tolower $myname];
    set left [string tolower $left];
    set across [string tolower $across];
    set right [string tolower $right];

    set gbvars(self,name) $myname;
    set gbvars(left,name) $left;
    set gbvars(right,name) $right;
    set gbvars(across,name) $across;
    set gbvars(game) "";
    set gbvars(cardbuttons) "";

    frame .gb;

    label .gb.gname;
    pack .gb.gname -side top -fill x;

    label .gb.gmsg;
    pack .gb.gmsg -side top -fill x;

    set gb_width 150;
    set gb_height 150;
    set a_height 85;
    set lr_width 100;
    set s_height 125;

    frame .gb.across -width [expr $lr_width * 2 + $gb_width] \
	    -height $a_height -relief raised -borderwidth 3;
    pack propagate .gb.across 0;
    pack .gb.across -side top -fill both -expand 1;

    frame .gb.self -width [expr $lr_width * 2 + $gb_width] \
	    -height $s_height -relief raised  -borderwidth 3;
    pack propagate .gb.self 0;
    pack .gb.self -side bottom -fill both -expand 1;

    frame .gb.left -width $lr_width -height $gb_height -relief raised  -borderwidth 3;
    pack propagate .gb.left 0;
    pack .gb.left -side left -fill both -expand 1;
 
    frame .gb.right -width $lr_width -height $gb_height -relief raised  -borderwidth 3;
    pack propagate .gb.right 0;
    pack .gb.right -side right -fill both -expand 1;
 
    frame .gb.parea -width $gb_width -height $gb_height;
    pack propagate .gb.parea 0;
    pack .gb.parea -fill both -expand 1

    bind .gb <Configure> {set w [expr [winfo width .gb] * 42 / 100]; .gb.parea configure -width $w};

    ClearTable;

    frame .gb.parea.acard;
    frame .gb.parea.lcard;
    frame .gb.parea.rcard;
    frame .gb.parea.scard;

    # Widgets for dominoes.

    label .gb.parea.low -text "Low";
    label .gb.parea.start -text "Start";
    label .gb.parea.high -text "High";
    frame .gb.parea.ls;
    frame .gb.parea.ss;
    frame .gb.parea.hs;
    frame .gb.parea.lh;
    frame .gb.parea.sh;
    frame .gb.parea.hh;
    frame .gb.parea.ld;
    frame .gb.parea.sd;
    frame .gb.parea.hd;
    frame .gb.parea.lc;
    frame .gb.parea.sc;
    frame .gb.parea.hc;

    pack .gb -fill both -expand 1;

    pack [label .gb.across.n -text $across] -side top;
    pack [label .gb.left.n -text $left] -side top;
    pack [label .gb.right.n -text $right] -side top;
    pack [label .gb.self.n -text $myname] -side top;

    pack [label .gb.across.m1] -side top;
    pack [label .gb.left.m1] -side top;
    pack [label .gb.right.m1] -side top;
    pack [label .gb.self.m1] -side top;

    pack [frame .gb.across.m2] -side top;
    pack [frame .gb.left.m2] -side top;
    pack [frame .gb.right.m2] -side top;
    pack [frame .gb.self.m2] -side top;
    
    pack [label .gb.across.m2.l -text "Last Card:"] -side left;
    pack [label .gb.left.m2.l -text "Last Card:"] -side left;
    pack [label .gb.right.m2.l -text "Last Card:"] -side left;
    pack [label .gb.self.m2.l -text "Last Card:"] -side left;

    pack [label .gb.across.m2.li] -side right;
    pack [label .gb.left.m2.li] -side right;
    pack [label .gb.right.m2.li] -side right;
    pack [label .gb.self.m2.li] -side right;

    pack [label .gb.across.m3] -side top;
    pack [label .gb.left.m3] -side  top;
    pack [label .gb.right.m3] -side top;
    pack [label .gb.self.m3] -side top;

    pack [frame .gb.self.cards] -side top;

    pack [frame .gb.self.cards.s -border 2 -relief sunken] -side left;
    pack [frame .gb.self.cards.h -border 2 -relief sunken] -side left;
    pack [frame .gb.self.cards.c -border 2 -relief sunken] -side left;
    pack [frame .gb.self.cards.d -border 2 -relief sunken] -side left;

    CreateCardImages
}

proc SetGame {gname {msg ""}} {
    global gbvars;

    set gbvars(game) $gname;
    .gb.gname configure -text "Current games is: $gname $msg";
}

proc SetHand {cards} {
    global gbvars;

    set cards [lsort -integer -increasing $cards];

    set gbvars(self,hand) $cards;

    DrawHand;
}

proc CreateCardImages {} {
    global gvars;

    set spddata {
	#define spd_width 20
	#define spd_height 20 
	static unsigned char spd_bits[] = {
	    0x00, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x0f, 0x00, 0x80, 0x1f, 0x00,
	    0xc0, 0x3f, 0x00, 0xe0, 0x7f, 0x00, 0xf0, 0xff, 0x00, 0xf8, 0xff, 0x01,
	    0xfc, 0xff, 0x03, 0xfc, 0xff, 0x03, 0xfc, 0xff, 0x03, 0xfc, 0xff, 0x03,
	    0xfc, 0xff, 0x03, 0xf8, 0xff, 0x01, 0xf0, 0xff, 0x00, 0x00, 0x06, 0x00,
	    0x00, 0x0f, 0x00, 0x00, 0x0f, 0x00, 0xf0, 0xff, 0x00, 0x00, 0x00, 0x00
	}
    }

    set clbdata {
	#define clb_width 20
	#define clb_height 20
	static unsigned char clb_bits[] = {
	    0x00, 0x00, 0x00, 0x00, 0x06, 0x00, 0x80, 0x1f, 0x00, 0xc0, 0x3f, 0x00,
	    0xc0, 0x3f, 0x00, 0xe0, 0x7f, 0x00, 0xe0, 0x7f, 0x00, 0xc0, 0x3f, 0x00,
	    0xc0, 0x3f, 0x00, 0xf0, 0xff, 0x00, 0xfc, 0xff, 0x03, 0xfc, 0xff, 0x03,
	    0xfe, 0xff, 0x07, 0xfe, 0xff, 0x07, 0xfc, 0xff, 0x03, 0x3c, 0xcf, 0x03,
	    0x30, 0xc6, 0x00, 0x00, 0x06, 0x00, 0xf8, 0xff, 0x01, 0x00, 0x00, 0x00
	}
    }

    set hrtdata {
	#define hrt_width 20
	#define hrt_height 20
	static unsigned char hrt_bits[] = {
	    0x00, 0x00, 0x00, 0xf0, 0xf0, 0x00, 0xf8, 0xf9, 0x01, 0xfc, 0xf9, 0x03,
	    0xfc, 0xff, 0x03, 0xfe, 0xff, 0x07, 0xfe, 0xff, 0x07, 0xfe, 0xff, 0x07,
	    0xfc, 0xff, 0x03, 0xfc, 0xff, 0x03, 0xf8, 0xff, 0x01, 0xf8, 0xff, 0x01,
	    0xf0, 0xff, 0x00, 0xe0, 0x7f, 0x00, 0xe0, 0x7f, 0x00, 0xc0, 0x3f, 0x00,
	    0x80, 0x1f, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x00
	}
    }

    set dmddata {
	#define dmd_width 20
	#define dmd_height 20
	static unsigned char dmd_bits[] = {
	    0x00, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x0f, 0x00, 0x80, 0x1f, 0x00,
	    0xc0, 0x3f, 0x00, 0xe0, 0x7f, 0x00, 0xf0, 0xff, 0x00, 0xf8, 0xff, 0x01,
	    0xfc, 0xff, 0x03, 0xfe, 0xff, 0x07, 0xfe, 0xff, 0x07, 0xfc, 0xff, 0x03,
	    0xf8, 0xff, 0x01, 0xf0, 0xff, 0x00, 0xe0, 0x7f, 0x00, 0xc0, 0x3f, 0x00,
	    0x80, 0x1f, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x00
	}
    }

    set m2 {
	#define m2_width 20
	#define m2_height 20
	static unsigned char m2_bits[] = {
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xf0, 0x0f, 0x7f, 0xe6, 0x0f, 0x7f, 0xe6, 0x0f,
	    0xff, 0xe7, 0x0f, 0xff, 0xf3, 0x0f, 0xff, 0xf9, 0x0f, 0xff, 0xfc, 0x0f,
	    0x7f, 0xfe, 0x0f, 0x7f, 0xe0, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f
	}
    }

    set m3 {
	#define m3_width 20
	#define m3_height 20
	static unsigned char m3_bits[] = {
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xf0, 0x0f, 0x7f, 0xe6, 0x0f, 0x7f, 0xe6, 0x0f,
	    0xff, 0xe7, 0x0f, 0xff, 0xf1, 0x0f, 0xff, 0xe7, 0x0f, 0x7f, 0xe6, 0x0f,
	    0x7f, 0xe6, 0x0f, 0xff, 0xf0, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f
	}
    }

    set m4 {
	#define m4_width 20
	#define m4_height 20
	static unsigned char m4_bits[] = {
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xfc, 0x0f, 0xff, 0xfc, 0x0f, 0xff, 0xe4, 0x0f,
	    0xff, 0xe4, 0x0f, 0xff, 0xe6, 0x0f, 0x7f, 0xe6, 0x0f, 0x7f, 0xe0, 0x0f,
	    0xff, 0xe7, 0x0f, 0xff, 0xe7, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f
	}
    }

    set m5 {
	#define m5_width 20
	#define m5_height 20
	static unsigned char m5_bits[] = {
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0x7f, 0xe0, 0x0f, 0x7f, 0xfe, 0x0f, 0x7f, 0xfe, 0x0f,
	    0x7f, 0xfe, 0x0f, 0x7f, 0xf0, 0x0f, 0xff, 0xe7, 0x0f, 0xff, 0xe7, 0x0f,
	    0xff, 0xf3, 0x0f, 0x7f, 0xf8, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f
	}
    }

    set m6 {
	#define m6_width 20
	#define m6_height 20
	static unsigned char m6_bits[] = {
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xf1, 0x0f, 0xff, 0xf9, 0x0f, 0xff, 0xfc, 0x0f,
	    0x7f, 0xf0, 0x0f, 0x7f, 0xe6, 0x0f, 0x7f, 0xe6, 0x0f, 0x7f, 0xe6, 0x0f,
	    0x7f, 0xe6, 0x0f, 0xff, 0xf0, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f
	}
    }

    set m7 {
	#define m7_width 20
	#define m7_height 20
	static unsigned char m7_bits[] = {
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0x7f, 0xe0, 0x0f, 0xff, 0xe7, 0x0f, 0xff, 0xf3, 0x0f,
	    0xff, 0xf3, 0x0f, 0xff, 0xf9, 0x0f, 0xff, 0xf9, 0x0f, 0xff, 0xfc, 0x0f,
	    0xff, 0xfc, 0x0f, 0xff, 0xfc, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f
	}
    }

    set m8 {
	#define m8_width 20
	#define m8_height 20
	static unsigned char m8_bits[] = {
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xf0, 0x0f, 0x7f, 0xe6, 0x0f, 0x7f, 0xe6, 0x0f,
	    0x7f, 0xe4, 0x0f, 0xff, 0xf0, 0x0f, 0x7f, 0xe2, 0x0f, 0x7f, 0xe6, 0x0f,
	    0x7f, 0xe6, 0x0f, 0xff, 0xf0, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f
	}
    }

    set m9 {
	#define m9_width 20
	#define m9_height 20
	static unsigned char m9_bits[] = {
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xf0, 0x0f, 0x7f, 0xe6, 0x0f, 0x7f, 0xe6, 0x0f,
	    0x7f, 0xe6, 0x0f, 0x7f, 0xe6, 0x0f, 0xff, 0xe0, 0x0f, 0xff, 0xf3, 0x0f,
	    0xff, 0xf9, 0x0f, 0xff, 0xf8, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f
	}
    }

    set mT {
	#define mT_width 20
	#define mT_height 20
	static unsigned char mT_bits[] = {
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0x7f, 0xe0, 0x0f, 0x7f, 0xe0, 0x0f, 0xff, 0xf9, 0x0f,
	    0xff, 0xf9, 0x0f, 0xff, 0xf9, 0x0f, 0xff, 0xf9, 0x0f, 0xff, 0xf9, 0x0f,
	    0xff, 0xf9, 0x0f, 0xff, 0xf9, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f
	}
    }

    set mJ {
	#define mJ_width 20
	#define mJ_height 20
	static unsigned char mJ_bits[] = {
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xe7, 0x0f, 0xff, 0xe7, 0x0f, 0xff, 0xe7, 0x0f,
	    0xff, 0xe7, 0x0f, 0xff, 0xe7, 0x0f, 0xff, 0xe7, 0x0f, 0x7f, 0xe6, 0x0f,
	    0x7f, 0xe6, 0x0f, 0xff, 0xf0, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f
	}
    }


    set mQ {
	#define mQ_width 20
	#define mQ_height 20
	static unsigned char mQ_bits[] = {
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xf0, 0x0f, 0x7f, 0xe6, 0x0f, 0x7f, 0xe6, 0x0f,
	    0x7f, 0xe6, 0x0f, 0x7f, 0xe6, 0x0f, 0x7f, 0xe6, 0x0f, 0xff, 0xf0, 0x0f,
	    0xff, 0xf3, 0x0f, 0xff, 0xe7, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f
	}
    }

    set mK {
	#define mK_width 20
	#define mK_height 20
	static unsigned char mK_bits[] = {
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0x7f, 0xe6, 0x0f, 0x7f, 0xe6, 0x0f, 0x7f, 0xf2, 0x0f,
	    0x7f, 0xf2, 0x0f, 0x7f, 0xf8, 0x0f, 0x7f, 0xf2, 0x0f, 0x7f, 0xf2, 0x0f,
	    0x7f, 0xe6, 0x0f, 0x7f, 0xe6, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f
	}
    }

    set mA {
	#define mA_width 20
	#define mA_height 20
	static unsigned char mA_bits[] = {
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xf9, 0x0f, 0xff, 0xf0, 0x0f, 0x7f, 0xe6, 0x0f,
	    0x7f, 0xe6, 0x0f, 0x7f, 0xe6, 0x0f, 0x7f, 0xe0, 0x0f, 0x7f, 0xe6, 0x0f,
	    0x7f, 0xe6, 0x0f, 0x7f, 0xe6, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f,
	    0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f, 0xff, 0xff, 0x0f
	}
    }
	    
    foreach suit {spd hrt dmd clb} {
	switch $suit {
	    clb {set forecol black; set idata $clbdata}
	    spd {set forecol black; set idata $spddata}
	    hrt {set forecol red; set idata $hrtdata}
	    dmd {set forecol red; set idata $dmddata}
	}

	foreach rank {2 3 4 5 6 7 8 9 T J Q K A} {
	    switch $rank {
		2 {set mdata $m2}
		3 {set mdata $m3}
		4 {set mdata $m4}
		5 {set mdata $m5}
		6 {set mdata $m6}
		7 {set mdata $m7}
		8 {set mdata $m8}
		9 {set mdata $m9}
		T {set mdata $mT}
		J {set mdata $mJ}
		Q {set mdata $mQ}
		K {set mdata $mK}
		A {set mdata $mA}
	    }

#		puts "$suit$rank $idata $mdata $forecol"
	    image create bitmap $suit$rank -data $idata -maskdata $mdata -foreground  $forecol -background #d9d9d9;
	}
    }
}

proc MapCNumToImage {cnum} {
    set suit [expr $cnum / 13];
    set rank [expr $cnum % 13];

    switch $suit {
	0 {set suit spd}
	1 {set suit hrt}
	2 {set suit dmd}
	3 {set suit clb}
    }

    switch $rank {
	8 {set rank T}
	9 {set rank J}
	10 {set rank Q}
	11 {set rank K}
	12 {set rank A}
	default {set rank [expr $rank+2]}
    }

    return $suit$rank;
}

proc DrawHand {} {
    
    global gbvars;

    if {$gbvars(cardbuttons) != ""} {
	eval destroy $gbvars(cardbuttons);
	set gbvars(cardbuttons) "";
    }

    set num_cards [llength $gbvars(self,hand)];

    for {set i 0} {$i < $num_cards} {incr i} {
	set cnum [lindex $gbvars(self,hand) $i];

	set img [MapCNumToImage $cnum];

	set suit [expr $cnum / 13];
	set rank [expr $cnum % 13];
	
	switch $suit {
	    0 {
		set pframe .gb.self.cards.s;
	    }
	    1 {
		set pframe .gb.self.cards.h;
	    }
	    2 {
		set pframe .gb.self.cards.d;
	    }
	    3 {
		set pframe .gb.self.cards.c;
	    }
	}

	set newb [button $pframe.$rank -image $img -activeback green -command "PlayCard $cnum $pframe.$rank" -padx 0 -pady 0 -bd -1 -relief flat];

	if {$suit == 0} {
	    $newb configure -background yellow
	} elseif {$suit == 1} {
	    $newb configure -background yellow
	} elseif {$suit == 2} {
	    $newb configure -background yellow
	} else {
	    $newb configure -background yellow
	}	    
	$newb configure -disabledforeground "#737373"
	
	lappend gbvars(cardbuttons) $newb;
	pack $newb -side left;
    }
}

proc ClearTable {} {
    global gbvars;

    set gbvars(across,curcard) "";
    set gbvars(left,curcard) "";
    set gbvars(right,curcard) "";
    set gbvars(self,curcard) "";

    if {[info exists gbvars(across,curcardbut)]} {
	destroy $gbvars(across,curcardbut);
	unset gbvars(across,curcardbut);
    }
    if {[info exists gbvars(left,curcardbut)]} {
	destroy $gbvars(left,curcardbut);
	unset gbvars(left,curcardbut);
    }
    if {[info exists gbvars(right,curcardbut)]} {
	destroy $gbvars(right,curcardbut);
	unset gbvars(right,curcardbut);
    }
    if {[info exists gbvars(self,curcardbut)]} {
	destroy $gbvars(self,curcardbut);
	unset gbvars(self,curcardbut);
    }
}


proc EvalPlayableCards {lead} {

    global gbvars;

    if {$lead != ""} {
	set leadsuit [expr $lead / 13];
	set leadrank [expr $lead % 13];
    }

    set one_valid 0;
    set valid_cnum "";
    set valid_cnum_widg "";

    foreach cnum $gbvars(self,hand) {
	set suit [expr $cnum / 13];
	set rank [expr $cnum % 13];


	switch $gbvars(game) {
	    Hearts -
	    "KingOfHearts" {
		if {$lead != ""} {
		    if {[HaveSuit $leadsuit]} {
			if {$suit == $leadsuit} {
			    set valid 1;
			} else {
			    set valid 0;
			}
		    } else {
			set valid 1;
		    }
		} else {
		    if {[HaveOtherThanHeart]} {
			if {$suit != 1} {
			    set valid 1;
			} else {
			    set valid 0;
			}
		    } else {
			set valid 1;
		    }
		}
	    }
	    Tricks -
	    Queens -
	    "LastTwo" {
		if {$lead != ""} {
		    if {[HaveSuit $leadsuit]} {
			if {$suit == $leadsuit} {
			    set valid 1;
			} else {
			    set valid 0;
			}
		    } else {
			set valid 1;
		    }
		} else {
		    set valid 1;
		}
	    }

	    Trumps {
		if {$lead != ""} {
		    if {[HaveSuit $leadsuit]} {
			if {$suit == $leadsuit} {
			    if {$leadsuit == $gbvars(trumpsuit)} {
				if {[HaveHigherTrump]} {
				    if {$rank > [CurrentHighTrump]} {
					set valid 1;
				    } else {
					set valid 0;
				    }
				} else {
				    set valid 1;
				}
			    } else { 
				set valid 1;
			    }
			} else {
			    set valid 0;
			}
		    } else {
			if {[HaveSuit $gbvars(trumpsuit)]} {
			    if {[HaveHigherTrump]} {
				if {$suit == $gbvars(trumpsuit)} {
				    if {$rank > [CurrentHighTrump]} {
					set valid 1;
				    } else {
					set valid 0;
				    }
				} else {
				    set valid 0;
				}
			    } else {
				set valid 1;
			    }
			} else {
			    set valid 1;
			}
		    }
		} else {
		    set valid 1;
		}
	    }
	    Dominoes {
		set low $gbvars(dlo,$suit);
		set high $gbvars(dhi,$suit);

		set valid 0;
		if {$low != ""} {
		    if {[expr $rank + 1] == $low} {
			set valid 1;
		    }
		}
		if {$high != ""} {
		    if {[expr $rank - 1] == $high} {
			set valid 1;
		    }
		}
		if {$rank == $gbvars(dstart)} {
		    set valid 1;
		}
	    }
	}

	switch $suit {
	    0 {
		set pframe .gb.self.cards.s;
		set forecol yellow;
	    }
	    1 {
		set pframe .gb.self.cards.h;
		set forecol yellow;
	    }
	    2 {
		set pframe .gb.self.cards.d;
		set forecol yellow;
	    }
	    3 {
		set pframe .gb.self.cards.c;
		set forecol yellow;
	    }
	}

	if {$valid} {
	    $pframe.$rank configure -state normal -background $forecol;
	    incr one_valid 1;
	    set valid_cnum $cnum;
	    set valid_cnum_widg $pframe.$rank;
	} else {
	    $pframe.$rank configure -state disabled -background #d9d9d9;
	}
    }

    if {!$one_valid} {
	PlayCard {} {};
	return;
    } 

    global autoplay;

    if {$autoplay} {
	update;
	after 1 AutoPlayCard;
    }
}

proc AutoPlayCard {} {
    global gbvars;

    foreach cbutton $gbvars(cardbuttons) {
	set statecon [$cbutton configure -state];

	if {[lindex $statecon 4] != "disabled"} {
	    after 1 "$cbutton invoke";
	    return;
	}
    }
}

proc HaveSuit {suit} {
    global gbvars;

    foreach cnum $gbvars(self,hand) {
	set cs [expr $cnum / 13];

	if {$cs == $suit} {
	    return 1;
	}
    }
    return 0;
}

proc HaveOtherThanHeart {} {

    if {[HaveSuit 0]} {
	return 1;
    }
    if {[HaveSuit 2]} {
	return 1;
    } 
    if {[HaveSuit 3]} {
	return 1;
    }
    return 0;
}

proc HaveHigherTrump {} {
    global gbvars;

    set ts $gbvars(trumpsuit);
    set high [CurrentHighTrump];

    foreach cnum $gbvars(self,hand) {
	set s [expr $cnum / 13];

	if {$s == $ts} {
	    set r [expr $cnum % 13];

	    if {$r > $high} {
		return 1;
	    }
	}
    }
    return 0;
}

proc CurrentHighTrump {} {
    global gbvars;

    set high -1;
    set ts $gbvars(trumpsuit);

    foreach cnum [list $gbvars(across,curcard) $gbvars(left,curcard) \
	    $gbvars(right,curcard)] {
	if {$cnum != ""} {
	    set s [expr $cnum / 13];
	    if {$s == $ts} {
		set r [expr $cnum % 13];
		if {$r > $high} {
		    set high $r;
		}
	    }
	}
    }

    return $high;
}

proc SetTrump {suit} {
    global gbvars;

    set gbvars(trumpsuit) $suit;
}

proc SetDLow {suit rank} {
    global gbvars;

    set gbvars(dlo,$suit) $rank;
}

proc SetDHigh {suit rank} {
    global gbvars;

    set gbvars(dhi,$suit) $rank;
}

proc SetDStart {rank} {
    global gbvars;

    set gbvars(dstart) $rank;
}

proc InitDominoes {rank} {
    SetDLow 0 "";
    SetDLow 1 "";
    SetDLow 2 "";
    SetDLow 3 "";

    SetDHigh 0 "";
    SetDHigh 1 "";
    SetDHigh 2 "";
    SetDHigh 3 "";
    
    SetDStart $rank;

    eval destroy [pack slaves .gb.parea.ls];
    eval destroy [pack slaves .gb.parea.lh];
    eval destroy [pack slaves .gb.parea.ld];
    eval destroy [pack slaves .gb.parea.lc];

    eval destroy [pack slaves .gb.parea.ss];
    eval destroy [pack slaves .gb.parea.sh];
    eval destroy [pack slaves .gb.parea.sd];
    eval destroy [pack slaves .gb.parea.sc];

    eval destroy [pack slaves .gb.parea.hs];
    eval destroy [pack slaves .gb.parea.hh];
    eval destroy [pack slaves .gb.parea.hd];
    eval destroy [pack slaves .gb.parea.hc];
}

proc SetDealer {name} {
    global gbvars;

    set name [string tolower $name];

    .gb.self.n configure -text [string tolower $gbvars(self,name)];
    .gb.across.n configure -text [string tolower $gbvars(across,name)];
    .gb.left.n configure -text [string tolower $gbvars(left,name)];
    .gb.right.n configure -text [string tolower $gbvars(right,name)];

    if {[string compare $name $gbvars(self,name)] == 0} {
	.gb.self.n configure -text [string toupper $gbvars(self,name)];
	return;
    }

    if {[string compare $name $gbvars(across,name)] == 0} {
	.gb.across.n configure -text [string toupper $gbvars(across,name)];
	return;
    }

    if {[string compare $name $gbvars(left,name)] == 0} {
	.gb.left.n configure -text [string toupper $gbvars(left,name)];
	return;
    }

    if {[string compare $name $gbvars(right,name)] == 0} {
	.gb.right.n configure -text [string toupper $gbvars(right,name)];
	return;
    }
}

proc SetPlayTurn {name} {
    global gbvars;

    set name [string tolower $name];

    .gb.self configure -background #d9d9d9;
    .gb.across configure -background #d9d9d9;
    .gb.left configure -background #d9d9d9;
    .gb.right configure -background #d9d9d9;

    if {[string compare $name $gbvars(self,name)] == 0} {
	.gb.self configure -background yellow;
	set gbvars(myturn) 1;
	return;
    }

    set gbvars(myturn) 0;

    if {[string compare $name $gbvars(across,name)] == 0} {
	.gb.across configure -background yellow;
	return;
    }

    if {[string compare $name $gbvars(left,name)] == 0} {
	.gb.left configure -background yellow;
	return;
    }

    if {[string compare $name $gbvars(right,name)] == 0} {
	.gb.right configure -background yellow;
	return;
    }
}

proc SetLastCard {name card led} {
    global gbvars;

    set name [string tolower $name];

    set img [MapCNumToImage $card];
    
    switch $name \
	    [set gbvars(across,name)] {
	.gb.across.m2.li configure -image $img
    } \
	    [set gbvars(left,name)] {
	.gb.left.m2.li configure -image $img
    } \
	    [set gbvars(right,name)] {
	.gb.right.m2.li configure -image $img
    } \
	    [set gbvars(self,name)] {
	.gb.self.m2.li configure -image $img
    } 
}    

proc SetMsgOne {name msg} {
    set name [string tolower $name];
    
    global gbvars;

    switch $name \
	    [set gbvars(across,name)] {
	.gb.across.m1 configure -text $msg
    } \
	    [set gbvars(left,name)] {
	.gb.left.m1 configure -text $msg
    } \
	    [set gbvars(right,name)] {
	.gb.right.m1 configure -text $msg
    } \
	    [set gbvars(self,name)] {
	.gb.self.m1 configure -text $msg
    }
}

proc SetMsgThree {name msg} {
    set name [string tolower $name];
    
    global gbvars;

    switch $name \
	    [set gbvars(across,name)] {
	.gb.across.m3 configure -text $msg
    } \
	    [set gbvars(left,name)] {
	.gb.left.m3 configure -text $msg
    } \
	    [set gbvars(right,name)] {
	.gb.right.m3 configure -text $msg
    } \
	    [set gbvars(self,name)] {
	.gb.self.m3 configure -text $msg
    }
}

proc PostPlay {name card} {
    global gbvars;

    set name [string tolower $name];

    set cardbut [CreateCardButton $card];

    set suit [expr $card / 13 ];
    set rank [expr $card % 13];

    if {$gbvars(game) == "Dominoes"} {
	if {$rank == $gbvars(dstart)} {
	    SetDLow $suit $rank;
	    SetDHigh $suit $rank;
	    switch $suit {
		0 {pack $cardbut -in .gb.parea.ss}
		1 {pack $cardbut -in .gb.parea.sh}
		2 {pack $cardbut -in .gb.parea.sd}
		3 {pack $cardbut -in .gb.parea.sc}
	    }
	} elseif {[expr $rank + 1] == $gbvars(dlo,$suit)} {
	    SetDLow $suit $rank;
	    switch $suit {
		0 {
		    eval destroy [pack slaves .gb.parea.ls];
		    pack $cardbut -in .gb.parea.ls;
		}
		1 {
		    eval destroy [pack slaves .gb.parea.lh];
		    pack $cardbut -in .gb.parea.lh;
		}
		2 {
		    eval destroy [pack slaves .gb.parea.ld];
		    pack $cardbut -in .gb.parea.ld;
		}
		3 {
		    eval destroy [pack slaves .gb.parea.lc];
		    pack $cardbut -in .gb.parea.lc;
		}
	    }
	} elseif {[expr $rank - 1] == $gbvars(dhi,$suit)} {
	    SetDHigh $suit $rank;
	    switch $suit {
		0 {
		    eval destroy [pack slaves .gb.parea.hs];
		    pack $cardbut -in .gb.parea.hs;
		}
		1 {
		    eval destroy [pack slaves .gb.parea.hh];
		    pack $cardbut -in .gb.parea.hh;
		}
		2 {
		    eval destroy [pack slaves .gb.parea.hd];
		    pack $cardbut -in .gb.parea.hd;
		}
		3 {
		    eval destroy [pack slaves .gb.parea.hc];
		    pack $cardbut -in .gb.parea.hc;
		}
	    }
	}
    } else {
	switch $name \
		[set gbvars(across,name)] {
	    set gbvars(across,curcardbut) $cardbut;
	    set gbvars(across,curcard) $card;
	    pack $cardbut -in .gb.parea.acard;
	} \
		[set gbvars(left,name)] {
	    set gbvars(left,curcardbut) $cardbut;
	    set gbvars(left,curcard) $card;
	    pack $cardbut -in .gb.parea.lcard;
	} \
		[set gbvars(right,name)] {
	    set gbvars(right,curcardbut) $cardbut;
	    set gbvars(right,curcard) $card;
	    pack $cardbut -in .gb.parea.rcard;
	} \
		[set gbvars(self,name)] {
	    set gbvars(self,curcardbut) $cardbut;
	    set gbvars(self,curcard) $card;
	    pack $cardbut -in .gb.parea.scard;
	}
    }
    update;
}

proc RankToValue {rank} {
    switch $rank {
	9 {
	    set value J;
	}
	10 {
	    set value Q;
	}
	11 {
	    set value K;
	}
	12 {
	    set value A;
	}
	default {
	    set value [expr $rank + 2];
	}
    }

    return $value;
}

proc PackForTricks {} {

    UnpackForDominoes;
    pack .gb.parea.acard -side top;
    pack .gb.parea.lcard -side left;
    pack .gb.parea.rcard -side right;
    pack .gb.parea.scard -side bottom
}

proc UnpackForTricks {} {
    pack forget .gb.parea.acard;
    pack forget .gb.parea.lcard;
    pack forget .gb.parea.rcard;
    pack forget .gb.parea.scard;
}

proc PackForDominoes {} {
    UnpackForTricks;

    grid .gb.parea.low -row 0 -column 0;
    grid .gb.parea.start -row 0 -column 1;
    grid .gb.parea.high -row 0 -column 2;
    
    grid .gb.parea.ls -row 1 -column 0;
    grid .gb.parea.ss -row 1 -column 1;
    grid .gb.parea.hs -row 1 -column 2;

    grid .gb.parea.lh -row 2 -column 0;
    grid .gb.parea.sh -row 2 -column 1;
    grid .gb.parea.hh -row 2 -column 2;

    grid .gb.parea.ld -row 3 -column 0;
    grid .gb.parea.sd -row 3 -column 1;
    grid .gb.parea.hd -row 3 -column 2;

    grid .gb.parea.lc -row 4 -column 0;
    grid .gb.parea.sc -row 4 -column 1;
    grid .gb.parea.hc -row 4 -column 2;
}

proc UnpackForDominoes {} {

    foreach sw {low start high ls ss hs lh sh hh ld sd hd lc sc hc} {
	eval destroy [pack slaves .gb.parea.$sw];
	grid forget .gb.parea.$sw;
    }
}

proc SetGMsg {msg} {
    .gb.gmsg configure -text $msg;
}

proc InitScoreboard {north east south west} {
    global sbvars;

    set subline1 "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------"

    set subline2 "============================================================================================================================================================================="

    toplevel .sb;

    scrollbar .sb.scroll -orient v

    pack .sb.scroll -side left -fill y;

    frame .sb.f
    pack .sb.f -fill both -expand 1;

    label .sb.n -text $north;
    label .sb.e -text $east;
    label .sb.s -text $south;
    label .sb.w -text $west;
    
    grid .sb.n -in .sb.f -column 1 -row 0 -sticky news;
    grid .sb.e -in .sb.f -column 2 -row 0 -sticky news;
    grid .sb.s -in .sb.f -column 3 -row 0 -sticky news;
    grid .sb.w -in .sb.f -column 4 -row 0 -sticky news;

    label .sb.tot -text "Total:"
    grid .sb.tot -in .sb.f -column 0 -row 0 -sticky news;

    set sbvars(n,total) 0;
    set sbvars(s,total) 0;
    set sbvars(e,total) 0;
    set sbvars(w,total) 0;

    label .sb.ntot -textvariable sbvars(n,total);
    grid .sb.ntot -in .sb.f -column 1 -row 1 -sticky news;
    label .sb.etot -textvariable sbvars(e,total);
    grid .sb.etot -in .sb.f -column 2 -row 1 -sticky news;
    label .sb.stot -textvariable sbvars(s,total);
    grid .sb.stot -in .sb.f -column 3 -row 1 -sticky news;
    label .sb.wtot -textvariable sbvars(w,total);
    grid .sb.wtot -in .sb.f -column 4 -row 1 -sticky news;

    canvas .sb.c;
    grid .sb.c -in .sb.f -column 0 -columnspan 5 -row 2 -sticky news;

    .sb.c configure -scrollregion [list 0 0 1000 1000];
    .sb.c configure -yscrollcommand ".sb.scroll set";
    .sb.scroll configure -command ".sb.c yview";

    frame .sb.c.f;

    .sb.c create window 0 0 -anchor nw -window .sb.c.f

    label .sb.c.f.n_q -text "Queens";
    grid .sb.c.f.n_q -in .sb.c.f -column 0 -row 0 -sticky news;

    label .sb.c.f.n_lt -text "Last 2";
    grid .sb.c.f.n_lt -in .sb.c.f -column 0 -row 1 -sticky news;

    label .sb.c.f.n_kh -text "K of H";
    grid .sb.c.f.n_kh -in  .sb.c.f -column 0 -row 2 -sticky news;

    label .sb.c.f.n_h -text "Hearts";
    grid .sb.c.f.n_h -in  .sb.c.f -column 0 -row 3 -sticky news;

    label .sb.c.f.n_t -text "Tricks";
    grid .sb.c.f.n_t -in .sb.c.f -column 0 -row 4 -sticky news;

    label .sb.c.f.n_tr -text "Trumps";
    grid .sb.c.f.n_tr -in .sb.c.f -column 0 -row 5 -sticky news;

    label .sb.c.f.n_d -text "Dom's";
    grid .sb.c.f.n_d -in  .sb.c.f -column 0 -row 6 -sticky news;

    frame .sb.c.f.n_sl1 -borderwidth 2 -relief raised -height 2;
    grid .sb.c.f.n_sl1 -in .sb.c.f -column 0 -row 7 -columnspan 5 -sticky news;

    label .sb.c.f.n_sub -text "Sub:";
    grid .sb.c.f.n_sub -in .sb.c.f -column 0 -row 8 -sticky news;

    frame .sb.c.f.n_sl2 -borderwidth 2 -relief raised -height 4;
    grid .sb.c.f.n_sl2 -in .sb.c.f -column 0 -row 9 -columnspan 5 -sticky news;

    label .sb.c.f.e_q -text "Queens";
    grid .sb.c.f.e_q -in  .sb.c.f -column 0 -row 10 -sticky news;

    label .sb.c.f.e_lt -text "Last 2";
    grid .sb.c.f.e_lt -in  .sb.c.f -column 0 -row 11 -sticky news;

    label .sb.c.f.e_kh -text "K of H";
    grid .sb.c.f.e_kh -in  .sb.c.f -column 0 -row 12 -sticky news;

    label .sb.c.f.e_h -text "Hearts";
    grid .sb.c.f.e_h -in  .sb.c.f -column 0 -row 13 -sticky news;

    label .sb.c.f.e_t -text "Tricks";
    grid .sb.c.f.e_t -in  .sb.c.f -column 0 -row 14 -sticky news;

    label .sb.c.f.e_tr -text "Trumps";
    grid .sb.c.f.e_tr -in  .sb.c.f -column 0 -row 15 -sticky news;

    label .sb.c.f.e_d -text "Dom's";
    grid .sb.c.f.e_d -in  .sb.c.f -column 0 -row 16 -sticky news;

    frame .sb.c.f.e_sl1 -borderwidth 2 -relief raised -height 2;
    grid .sb.c.f.e_sl1 -in .sb.c.f -column 0 -row 17 -columnspan 5 -sticky news;

    label .sb.c.f.e_sub -text "Sub:";
    grid .sb.c.f.e_sub -in  .sb.c.f -column 0 -row 18 -sticky news;

    frame .sb.c.f.e_sl2 -borderwidth 2 -relief raised -height 4;
    grid .sb.c.f.e_sl2 -in .sb.c.f -column 0 -row 19 -columnspan 5 -sticky news;

    label .sb.c.f.s_q -text "Queens";
    grid .sb.c.f.s_q -in  .sb.c.f -column 0 -row 20 -sticky news;

    label .sb.c.f.s_lt -text "Last 2";
    grid .sb.c.f.s_lt -in  .sb.c.f -column 0 -row 21 -sticky news;

    label .sb.c.f.s_kh -text "K of H";
    grid .sb.c.f.s_kh -in  .sb.c.f -column 0 -row 22 -sticky news;

    label .sb.c.f.s_h -text "Hearts";
    grid .sb.c.f.s_h -in  .sb.c.f -column 0 -row 23 -sticky news;

    label .sb.c.f.s_t -text "Tricks";
    grid .sb.c.f.s_t -in  .sb.c.f -column 0 -row 24 -sticky news;

    label .sb.c.f.s_tr -text "Trumps";
    grid .sb.c.f.s_tr -in  .sb.c.f -column 0 -row 25 -sticky news;

    label .sb.c.f.s_d -text "Dom's";
    grid .sb.c.f.s_d -in  .sb.c.f -column 0 -row 26 -sticky news;

    frame .sb.c.f.s_sl1 -borderwidth 2 -relief raised -height 2;
    grid .sb.c.f.s_sl1 -in .sb.c.f -column 0 -row 27 -columnspan 5 -sticky news;

    label .sb.c.f.s_sub -text "Sub:";
    grid .sb.c.f.s_sub -in  .sb.c.f -column 0 -row 28 -sticky news;

    frame .sb.c.f.s_sl2 -borderwidth 2 -relief raised -height 4;
    grid .sb.c.f.s_sl2 -in .sb.c.f -column 0 -row 29 -columnspan 5 -sticky news;

    label .sb.c.f.w_q -text "Queens";
    grid .sb.c.f.w_q -in  .sb.c.f -column 0 -row 30 -sticky news;

    label .sb.c.f.w_lt -text "Last 2";
    grid .sb.c.f.w_lt -in .sb.c.f -column 0 -row 31 -sticky news;

    label .sb.c.f.w_kh -text "K of H";
    grid .sb.c.f.w_kh -in .sb.c.f -column 0 -row 32 -sticky news;

    label .sb.c.f.w_h -text "Hearts";
    grid .sb.c.f.w_h -in  .sb.c.f -column 0 -row 33 -sticky news;

    label .sb.c.f.w_t -text "Tricks";
    grid .sb.c.f.w_t -in  .sb.c.f -column 0 -row 34 -sticky news;

    label .sb.c.f.w_tr -text "Trumps";
    grid .sb.c.f.w_tr -in .sb.c.f -column 0 -row 35 -sticky news;

    label .sb.c.f.w_d -text "Dom's";
    grid .sb.c.f.w_d -in  .sb.c.f -column 0 -row 36 -sticky news;

    frame .sb.c.f.w_sl1 -borderwidth 2 -relief raised -height 2;
    grid .sb.c.f.w_sl1 -in .sb.c.f -column 0 -row 37 -columnspan 5 -sticky news;

    label .sb.c.f.w_sub -text "Sub:";
    grid .sb.c.f.w_sub -in .sb.c.f -column 0 -row 38 -sticky news;

    foreach dealer {n s e w} {
	switch $dealer {
	    n {set dr 0}
	    e {set dr 1}
	    s {set dr 2}
	    w {set dr 3}
	}

	foreach player {n s e w} {
	    switch $player {
		n {set col 1}
		e {set col 2}
		s {set col 3}
		w {set col 4}
	    }

	    foreach game {q lt kh h t tr d sub} {
		switch $game {
		    q {set gr 0}
		    lt {set gr 1}
		    kh {set gr 2}
		    h {set gr 3}
		    t {set gr 4}
		    tr {set gr 5}
		    d {set gr 6}
		    sub {set gr 8}
		}

		if {$game == "sub"} {
		    set ival 0;
		} else {
		    set ival "";
		}

		set sbvars($dealer,$player,$game) $ival;
		label .sb.c.f.${dealer}_${player}_${game} -textvariable sbvars($dealer,$player,$game);
		set row [expr ($dr * 10) + $gr];
		grid .sb.c.f.${dealer}_${player}_${game} -in .sb.c.f -column $col -row $row -sticky news;

		if {[string compare $player $dealer] == 0} {
		    .sb.c.f.${dealer}_${player}_${game} configure -foreground red;
		}
	    }
	}
    }

    grid columnconfigure .sb.f 0 -minsize 50;

    bind .sb.f <Configure> "DoConfig3; update; DoConfig2 0; DoConfig2 1; DoConfig2 2; DoConfig2 3; DoConfig2 4";

    bind .sb.c.f <Configure> DoConfig1;
    update;
}

proc DoConfig1 {} {

    set w [winfo width .sb.c.f];
    set h [winfo height .sb.c.f];

    .sb.c configure -scrollregion [list 0 0 $w $h];
}

proc DoConfig2 {col} {
    set info [grid bbox .sb.f $col 0];
    set width [lindex $info 2];

    grid columnconfigure .sb.c.f $col -minsize $width -weight 0;
}

proc DoConfig3 {} {
    set width [winfo width .sb.f];
    set height [winfo height .sb.f];
    set info [grid bbox .sb.f 0 2];
    set dy [lindex $info 1];
    set height [expr $height - $dy];
	set fb [lindex [.sb.f configure -bd] 4];
	set cdw [expr [winfo width .sb.c] - [lindex [.sb.c config -width] 4]];
	set cdh [expr [winfo height .sb.c] - [lindex [.sb.c config -height] 4]];

    .sb.c configure -width [expr $width - $cdw - (2*$fb)] \
			-height [expr $height - $cdh - (1 * $fb)];
}

proc PostScore {dealer player game score} {
    global sbvars;

    set sbvars($dealer,$player,$game) $score;

    set sbvars($dealer,$player,sub) [expr $sbvars($dealer,$player,sub) + $score];
    set sbvars($player,total) [expr $sbvars($player,total) + $score];
}

proc PostTotal {player total} {
    global sbvars;

    set sbvars($player,total) $total;
}

proc DoDoubleDlog {msg1 msg2 dlist} {
    global dblvars;

    if {[info exists dblvars]} {
	unset dblvars;
    }

    toplevel .dlog;

    label .dlog.m1 -text $msg1;
    label .dlog.m2 -text $msg2;

    pack .dlog.m1 -side top;
    pack .dlog.m2 -side top;

    foreach entry $dlist {
	set name [lindex $entry 0];
	set curfactor [lindex $entry 1];
	set forced [lindex $entry 2];

	lappend dblvars(nlist) $name;

	set dblvars($name) 0;
	set dblvars($name,value) $curfactor;

	switch $curfactor {
	    0 {
		checkbutton .dlog.$name -text "Double $name" -variable dblvars($name);
	    }
	    1 {
		checkbutton .dlog.$name -text "Redouble $name" -variable dblvars($name);
	    }
	}

	if {$forced} {
	    set dblvars($name) 1;
	    .dlog.$name configure -state disabled;
	}

	pack .dlog.$name -side top;
    }

    button .dlog.ok -text "OK" -command "ReportDoubles"

    pack .dlog.ok -side top;

    global autoplay;

    if {$autoplay} {
	update;
	after 1 AutoReportDoubles;
    }
}

proc AutoReportDoubles {} {
    global dblvars;

    foreach name $dblvars(nlist) {
	set do_double [expr [clock clicks] % 2];

	if {$do_double} {
	    set dblvars($name) 1;
	}
    }
    ReportDoubles;
}

proc ReportDoubles {} {
    global server;

    global dblvars;

    global gbvars;

    set res "";
    foreach name $dblvars(nlist) {
	if {$dblvars($name)} {
	    set factor [expr $dblvars($name,value) + 1];
	    lappend res [list $name $factor];
	}
    }

    dp_RDO $server ReportDoubles $gbvars(self,name) $res;

    destroy .dlog;
}

proc PlayCard {cnum widg} {
    global gbvars;
    global server;

    if {$gbvars(myturn)} {
	set gbvars(myturn) 0;
	if {$gbvars(playmode)} {
	    if {$widg != ""} {
		$widg configure -state disabled -background #d9d9d9;
		pack forget $widg;
	    }

	    dp_RDO $server ReportCard $gbvars(self,name) $cnum;
	    
	    # Remove card from hand.
	    if {$cnum != ""} {
		set idx [lsearch $gbvars(self,hand) $cnum];
		if {$idx != -1} {
		    set gbvars(self,hand) [lreplace $gbvars(self,hand) $idx $idx];
		}
	    }
	}   
    }
}

proc SetPlayMode {mode} {
    global gbvars;

    .gb.self configure -background #d9d9d9;
    .gb.across configure -background #d9d9d9;
    .gb.left configure -background #d9d9d9;
    .gb.right configure -background #d9d9d9;

    set gbvars(playmode) $mode;
}

proc DoGameChoice {glist} {

    toplevel .gchoice;

    set aplay 0;

    label .gchoice.m1 -text "Choose a game: ";

    pack .gchoice.m1 -side top;

    foreach entry $glist {
	set gname [lindex $entry 0];
	set gvalue [lindex $entry 1];

	button .gchoice.$gvalue -text $gname -command "ReportGameChoice $gvalue";
	pack .gchoice.$gvalue -side top;
	
	global autoplay;

	if {$autoplay} {
	    if {!$aplay} {
		after 1 ".gchoice.$gvalue invoke";
		set aplay 1;
	    }
	}
    }
}

proc ReportGameChoice {gvalue} {
    global gbvars;
    global server;

    dp_RDO $server ReportGameChoice $gvalue;

    destroy .gchoice;
}

   
proc DoDominoesRankChoice {} {
    global gbvars;

    toplevel .drank;

    label .drank.l -text "Start Dominoes from: ";
    
    button .drank.b1 -text "2" -padx 1 -pady 1 -command "ReportDominoesRankChoice 0";
    button .drank.b2 -text "3" -padx 1 -pady 1 -command "ReportDominoesRankChoice 1";
    button .drank.b3 -text "4" -padx 1 -pady 1 -command "ReportDominoesRankChoice 2";
    button .drank.b4 -text "5" -padx 1 -pady 1 -command "ReportDominoesRankChoice 3";
    button .drank.b5 -text "6" -padx 1 -pady 1 -command "ReportDominoesRankChoice 4";
    button .drank.b6 -text "7" -padx 1 -pady 1 -command "ReportDominoesRankChoice 5";
    button .drank.b7 -text "8" -padx 1 -pady 1 -command "ReportDominoesRankChoice 6";
    button .drank.b8 -text "9" -padx 1 -pady 1 -command "ReportDominoesRankChoice 7";
    button .drank.b9 -text "10" -padx 1 -pady 1 -command "ReportDominoesRankChoice 8";
    button .drank.b10 -text "J" -padx 1 -pady 1 -command "ReportDominoesRankChoice 9";
    button .drank.b11 -text "Q" -padx 1 -pady 1 -command "ReportDominoesRankChoice 10";
    button .drank.b12 -text "K" -padx 1 -pady 1 -command "ReportDominoesRankChoice 11";
    button .drank.b13 -text "A" -padx 1 -pady 1 -command "ReportDominoesRankChoice 12";

    pack .drank.l -side top;
    pack .drank.b1 -side left;
    pack .drank.b2 -side left;
    pack .drank.b3 -side left;
    pack .drank.b4 -side left;
    pack .drank.b5 -side left;
    pack .drank.b6 -side left;
    pack .drank.b7 -side left;
    pack .drank.b8 -side left;
    pack .drank.b9 -side left;
    pack .drank.b10 -side left;
    pack .drank.b11 -side left;
    pack .drank.b12 -side left;
    pack .drank.b13 -side left;

    global autoplay;

    if {$autoplay} {
	update;
	after 1 ".drank.b7 invoke";
    }
}

proc ReportDominoesRankChoice {rank} {
    global server;

    dp_RDO $server ReportDominoesRankChoice $rank;

    destroy .drank;
}

proc InitChat {} {
    toplevel .chat;

    scrollbar .chat.sb -orient vertical;
    
    text .chat.txt -width 55 -state disabled;

    entry .chat.e;

    bind .chat.e <KeyPress-Return> ReportChatMsg;

    pack .chat.sb -side left -fill y;
    pack .chat.txt -side top -fill both -expand 1;
    pack .chat.e -side top -fill x;

    .chat.sb configure -command ".chat.txt yview"
    .chat.txt configure -yscrollcommand ".chat.sb set"

    .chat.txt tag configure self -foreground black -lmargin2 50;
    .chat.txt tag configure across -foreground red -lmargin2 50;
    .chat.txt tag configure left -foreground blue -lmargin2 50;
    .chat.txt tag configure right -foreground purple -lmargin2 50;
    .chat.txt tag configure system -foreground brown -lmargin2 50;

    .chat.txt configure -tabs 50;
    .chat.txt configure -wrap word;
}

proc ReportChatMsg {} {
    global server;
    global gbvars;

    set txt [.chat.e get];

    dp_RDO $server ReportChatMsg $gbvars(self,name) $txt;

    .chat.e delete 0 end;
}

proc PostChatMsg {name msg} {
    global gbvars;

    switch $name \
	    $gbvars(self,name) {set tag self} \
	    $gbvars(left,name) {set tag left} \
	    $gbvars(across,name) {set tag across} \
	    $gbvars(right,name) {set tag right} \
	    system {set tag system}
    
    .chat.txt configure -state normal;
    .chat.txt insert end "$name:\t$msg\n" $tag;
    .chat.txt configure -state disabled;
    .chat.txt see end
}
    
proc CreateCardButton {cnum} {
    
    set img [MapCNumToImage $cnum];

    set suit [expr $cnum / 13];
    set rank [expr $cnum % 13];

    set cb [button .$suit$rank -image $img -padx 0 -pady 0 -bd -1 -relief flat];

    if {$suit == 0} {
	$cb configure -background yellow -activeback yellow;
    } elseif {$suit == 1} {
	$cb configure -background yellow -activeback yellow;
    } elseif {$suit == 2} {
	$cb configure -background yellow -activeback yellow;
    } else {
	$cb configure -background yellow -activeback yellow;
    }	    

    return $cb;
}
    

proc RegisterWithServer {host port myname} {
    global server;

    set server [dp_MakeRPCClient $host $port];

    dp_RDO $server Register $myname;
}

frame .s
label .s.l -text "Server: "
entry .s.e
.s.e insert 0 "152.2.131.167"
pack .s.l -side left;
pack .s.e -side right -expand 1 -fill y
frame .p
label .p.l -text "Port: "
entry .p.e
.p.e insert 0 "5757"
pack .p.l -side left;
pack .p.e -side right -expand 1 -fill y
frame .n
label .n.l -text "Name: "
entry .n.e
.n.e insert 0 "loser@[exec hostname]"
pack .n.l -side left;
pack .n.e -side right -expand 1 -fill y
button .b -text "Register" -command {
    set s [.s.e get]
    set p [.p.e get]
    set n [.n.e get]
    after 100 RegisterWithServer $s $p $n
    destroy .s.l
    destroy .s.e
    destroy .s
    destroy .p.l
    destroy .p.e
    destroy .p
    destroy .n.l
    destroy .n.e
    destroy .n
    destroy .b
}
pack .s
pack .p
pack .n
pack .b
