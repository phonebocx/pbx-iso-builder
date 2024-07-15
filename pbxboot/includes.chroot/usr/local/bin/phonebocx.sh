#!/bin/bash

IP=$(ip -o addr show dev eth0 | awk '/inet / { print $4 }')
# Devmode check - are we in au? This needs to be less hardcoded 8)
if echo $IP | grep -q 10.46; then
    mkdir -p /pbxdev
    grep -q pbxdev /proc/mounts || mount repo.phonebo.cx:/livebuild/packages /pbxdev
fi

THISTTY=$(tty | sed 's!/dev/!!')

echo "eth0 IP Address $IP"

DIRS="/factory/core /pbxdev/core /pbx/core"
for d in $DIRS; do
    tfile=$d/$THISTTY.sh
    if [ -x $tfile ]; then
        echo "I think $tfile is good"
        exec $tfile
        echo "How am I here?"
        exit 9
    fi
done

echo "/usr/local/bin/phonebocx.sh running on $THISTTY"
echo "There is no bootfile for this tty"
sleep infinity

