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

function get_this_ttyname() {
    tty 2>/dev/null | sed 's!/dev/!!'
}
