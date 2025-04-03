#!/bin/bash

# This makes sure nothing is messing up our fonts and ANSI parsing
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Look for a 1M block device attached to this host. If there is one,
# it should be a test disk (Created in Makefile.isotest). If it
# contains a line starting with 'nfs:', that's telling us to mount
# that to /pbxdev
export TESTDISK=$(grep -l 2048 /sys/class/block/*/size | cut -d/ -f5)
if [ "$TESTDISK" ]; then
    mkdir -p /pbxdev
    # Found it. Does it have a nfs line?
    NFSHINT=$(grep -a ^nfs /dev/$TESTDISK | cut -d: -f2-)
    if [ "$NFSHINT" ]; then
        # We have a hint! Mount it, if something isn't
        # already mounted there.
        if ! grep -q ' /pbxdev nfs' /proc/mounts; then
            mount $NFSHINT /pbxdev
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
