#!/bin/sh

. ../../common/procedures.sh

err=0

if isOSlinux; then
	ip link add name test0 type veth peer name test1
	ip link set test0 up
	ip link set test1 up
else
	test0=`printf "mkpeer eiface ether ether \n show .ether" | ngctl -f - | head -n1 | awk '{print $2}'`
	ngctl name $test0: test0
	ifconfig $test0 name test0
	ifconfig test0 up
	test1=`printf "mkpeer eiface ether ether \n show .ether" | ngctl -f - | head -n1 | awk '{print $2}'`
	ngctl name $test1: test1
	ifconfig $test1 name test1
	ifconfig test1 up

	ngctl mkpeer test0: pipe ether upper
	ngctl name test0:ether testlink
	ngctl connect testlink: test1: lower ether
	ngctl msg testlink: setcfg {header_offset=14}
fi

eid=`imunes -b extvlan.imn | tail -1 | cut -d' ' -f4`
startCheck "$eid"

netDump pc1@$eid eth0 icmp
if [ $? -eq 0 ]; then
    sleep 4
    pingCheck pc1@$eid 10.0.0.21 2
    if [ $? -eq 0 ]; then
	sleep 2
	readDump pc1@$eid eth0
	err=$?
    else
	err=1
    fi
else
    err=1
fi

imunes -b -e $eid

if isOSlinux; then
	ip link del test0
else
	ngctl msg testlink: shutdown
	ngctl msg test0: shutdown
	ngctl msg test1: shutdown
fi

thereWereErrors $err
