#!/bin/bash

function get_script_loc() {
    local scriptname=$1
    local dirs="/factory/core /pbxdev/core /pbx/core"
    for d in $dirs; do
        sfile=$d/$scriptname.sh
        if [ -x $sfile ]; then
            echo $sfile
            return
        fi
    done
}

IP=$(ip -o addr show dev eth0 | awk '/inet / { print $4 }')
THISTTY=$(tty 2>/dev/null | sed 's!/dev/!!')

# Devmode check - are we in au? This needs to be less hardcoded 8)
if echo $IP | grep -q 10.46; then
    mkdir -p /pbxdev
    grep -q pbxdev /proc/mounts || mount repo.phonebo.cx:/livebuild/packages /pbxdev
fi
