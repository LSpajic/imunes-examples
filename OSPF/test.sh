#!/bin/sh

. ../common/procedures.sh

err=0
slow=1
legacy=""
if test -n "$LEGACY"; then
    legacy=" -l"
fi

eid=`imunes$legacy -b OSPF1.imn | awk '/Experiment/{print $4; exit}'`
startCheck "$eid"

Wait 40
netDump router2@$eid eth2
if [ $? -eq 0 ]; then
    n=1
    pingStatus=1
    while [ $n -le 20 ] && [ $pingStatus -ne 0 ]; do
        echo "Ping test $n / 20 ..."
        pingCheck pc@$eid 10.0.4.10 2
        pingStatus=$?
        n=`expr $n + 1`
    done
    if [ $pingStatus -eq 0 ]; then
	echo "########## router2@$eid routes"
	himage -nt router2@$eid vtysh << __END__
	show ip ospf route
	show ipv6 ospf route
	exit
__END__
	sleep 2
	if [ $? -eq 0 ]; then
            n=1
            pingStatus=1
            while [ $n -le 20 ] && [ $pingStatus -ne 0 ]; do
                echo "Ping6 test $n / 20 ..."
                ping6Check pc@$eid fc00:1::10 2
                pingStatus=$?
                n=`expr $n + 1`
            done
            if [ $pingStatus -eq 0 ]; then
		sleep 2
		echo ""
		readDump router2@$eid eth2
		if [ $? -ne 0 ]; then
		    err=1
		fi
	    else
		err=1
	    fi
	else
	    err=1
	fi

	if [ $slow -eq 1 ]; then
	    if isOSlinux; then
		echo "Drop all packets between router2 and router7 (Loss=100%)"
		vlink -loss 100% -e $eid router2:router7
		waittime=40
	    else
		# This actually simulates interface down
		echo "Drop all packets between router2 and router7 (BER=1)"
		vlink -BER 1 -e $eid router2:router7
		waittime=5
	    fi
	    if [ $? -eq 0 ]; then
		Wait $waittime

		echo ""
		echo "########## router2@$eid routes after $waittime seconds"
		himage -nt router2@$eid vtysh << __END__ 
		show ip ospf route
		show ipv6 ospf route
		exit
__END__

		if isOSlinux; then
		    echo "Restore link between router2 and router7 (Loss=0%)"
		    vlink -loss 0% -e $eid router2:router7
		    waittime=10
		else
		    # This actually simulates interface up
		    echo "Restore link between router2 and router7 (BER=0)"
		    vlink -BER 0 -e $eid router2:router7
		    waittime=40
		fi
		if [ $? -eq 0 ]; then
		    Wait $waittime
                    n=1
                    pingStatus=1
                    while [ $n -le 20 ] && [ $pingStatus -ne 0 ]; do
                        echo "Ping test2 $n / 20 ..."
                        pingCheck pc@$eid 10.0.4.10 2
                        pingStatus=$?
                        n=`expr $n + 1`
                    done
                    if [ $pingStatus -eq 0 ]; then
			sleep 4
			readDump router2@$eid eth2
		    else
			err=1
		    fi
                    ping6Check pc@$eid fc00:1::10 2
                    n=1
                    pingStatus=1
                    while [ $n -le 20 ] && [ $pingStatus -ne 0 ]; do
                        echo "Ping6 test2 $n / 20 ..."
                        ping6Check pc@$eid fc00:1::10 2
                        pingStatus=$?
                        n=`expr $n + 1`
                    done
                    if [ $pingStatus -eq 0 ]; then
			sleep 4
			readDump router2@$eid eth2
		    else
			err=1
		    fi
		else
		    err=1
		fi
	    else
		err=1
	    fi
	fi
    else
	err=1
    fi
else
    err=1
fi

readDump router2@$eid eth2
imunes$legacy -b -e $eid

thereWereErrors $err
