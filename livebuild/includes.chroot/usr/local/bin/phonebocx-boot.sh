#!/bin/bash

# This makes sure nothing is messing up our fonts and ANSI parsing
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

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
