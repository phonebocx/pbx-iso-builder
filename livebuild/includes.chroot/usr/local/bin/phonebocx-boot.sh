#!/bin/bash

# This makes sure nothing is messing up our fonts and ANSI parsing
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Default mounting location
PBXDEV=/pbxdev
ALTPBXDEV=/pbxdev2

# Only look harder if we don't have a virtiofs mount already.
if ! grep -q ' virtiofs ' /proc/mounts; then
    # Are we using virtiofs? If so, there'll be a PCI device mass
    # storage controller called that.
    if lspci | grep -q 'Virtio file system'; then
        mkdir -p /vloopback
        # If it's not called that, don't mount it.
        mount -t virtiofs vloopback /vloopback
    fi
fi

# Was one mounted, or is one mounted?
if grep -q '^vloopback /vloopback ' /proc/mounts; then
    # Default dest to mount it
    BINDMOUNT=$PBXDEV
    # But if there's an override, use that
    [ -e /vloopback/bindmount ] && BINDMOUNT=$(cat /vloopback/bindmount)

    # Is there a boot-override debug script? Include that (don't run) so
    # it can update anything it wants to update
    [ -e /vloopback/boot-override.sh ] && . /vloopback/boot-override.sh

    # Finally, if there is a bindmount that's not null, check if it's
    # already been mounted, and mount it if needed
    if [ "$BINDMOUNT" ]; then
        if ! grep -q "^vloopback $BINDMOUNT virtiofs" /proc/mounts; then
            mkdir -p $BINDMOUNT
            mount --bind /vloopback $BINDMOUNT
        fi
    fi
fi

if grep -q " $PBXDEV " /proc/mounts; then
    NFSDEST=$ALTPBXDEV
else
    NFSDEST=$PBXDEV
fi

# Look for a 1M block device attached to this host. If there is one,
# it should be a test disk (Created in Makefile.isotest). If it
# contains a line starting with 'nfs:', that's telling us to mount
# that to /pbxdev
export TESTDISK=$(grep -l 2048 /sys/class/block/*/size | grep -v loop | cut -d/ -f5)
if [ "$TESTDISK" ]; then
    # Does that testdisk have a nfs line?
    NFSHINT=$(grep -a ^nfs /dev/$TESTDISK | cut -d: -f2-)
    if [ "$NFSHINT" ]; then
        # It does. If it's not mounted anywhere already, carry on
        if ! grep -q "^$NFSHINT " /proc/mounts; then
            mkdir -p $NFSDEST
            mount $NFSHINT $NFSDEST
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
