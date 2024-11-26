#!/bin/bash

function get_script_loc() {
    local pkgname=$1
    local scriptname=$2
    local dirs="/factory/$1 /pbxdev/$1 /pbx/$1"
    for d in $dirs; do
        sfile=$d/$scriptname.sh
        if [ -x $sfile ]; then
            echo $sfile
            return
        fi
    done
}

function get_ip_addr() {
    [ "$1" ] && unset IP
    if [ ! "$IP" ]; then
        IP=$(ip -o addr show | awk '/inet / { print $4 }' | tr '\n' ' ')
    fi
    echo $IP
}

function get_this_ttyname() {
    tty 2>/dev/null | sed 's!/dev/!!'
}

# Devmode check - are we in au? This needs to be less hardcoded 8)
if $(get_ip_addr | grep -q 10.46); then
    mkdir -p /pbxdev
    grep -q pbxdev /proc/mounts || mount -o actimeo=0 repo.phonebo.cx:/livebuild/packages /pbxdev
fi
