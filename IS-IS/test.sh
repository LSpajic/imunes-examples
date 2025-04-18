#!/bin/sh

. ../common/procedures.sh

err=0
slow=0
legacy=""
if test -n "$LEGACY"; then
    legacy=" -l"
fi

eid=`imunes$legacy -b IS-IS.imn | awk '/Experiment/{print $4; exit}'`
startCheck "$eid"

Wait 40

n=1
pingStatus=1
while [ $n -le 20 ] && [ $pingStatus -ne 0 ]; do
    echo "Ping test $n / 20 ..."
    pingCheck pc1@$eid 172.16.3.20 2
    pingStatus=$?
    n=`expr $n + 1`
done

if [ $pingStatus -ne 0 ]; then
    err=1
fi

for r in R1 R2 R3
do
    echo "########## $r@$eid routes"
    himage -nt $r@$eid vtysh << __END__
    show ip route
    exit
__END__
done

imunes$legacy -b -e $eid

thereWereErrors $err

