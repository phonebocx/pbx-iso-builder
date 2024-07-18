#!/bin/sh

# Override label
custom_overlay_label="siteconf"
PERSISTENCE="true"
export PERSISTENCE

if grep -q BOOT_IMAGE=/live /proc/cmdline; then
	NOPERSISTENCE="liveboot"
	export NOPERSISTENCE
fi


