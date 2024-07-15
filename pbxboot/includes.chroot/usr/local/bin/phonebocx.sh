#!/bin/bash

# Devmode check - are we in au? This needs to be less hardcoded 8)
if ip -o addr | grep -q 10.46; then
    mkdir -p /pbxdev
    grep -q pbxdev /proc/mounts || mount repo.phonebo.cx:/livebuild/packages /pbxdev
fi

THISTTY=$(tty | sed 's!/dev/!!')

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

