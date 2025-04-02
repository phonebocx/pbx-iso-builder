#!/bin/bash

# This makes sure nothing is messing up our fonts and ANSI parsing
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# If we're in a test instance, /sys/class/dmi/id/board_vendor may contain
# 'nfs', which means we should mount whatever is there as /pbxdev
dmibase=/sys/class/dmi/id
if [ -e $dmibase/board_vendor ]; then
    if grep -q nfs $dmibase/board_vendor; then
        nfsmount=$(cat $dmibase/board_name):$(cat $dmibase/board_asset_tag)
        pbxdev=$(grep ' /pbxdev nfs' /proc/mounts)
        mkdir -p /pbxdev
        if [ ! "$pbxdev" ]; then
            # Nothing is mounted there, we're ok to mount now.
            mount $nfsmount /pbxdev
        else
            # Something is mounted there, is it what should be there?
            if ! grep -q "^$nfsmount /pbxdev nfs" /proc/mounts; then
                umount -f /pbxdev
                mount $nfsmount /pbxdev
            fi
        fi
    fi
fi

. /usr/local/bin/phonebocx-init.sh

echo $(date)": phonebocx-boot launched" >/dev/kmsg
bootscript=$(get_script_loc core boot)
if [ "$bootscript" ]; then
    cd $(dirname $bootscript)
    echo Launching bootscript $bootscript >/dev/kmsg
    exec $bootscript
fi

echo "Could not find bootscript. Sleeping and failing"
sleep 5
exit 255
