#!/bin/bash

. /usr/local/bin/phonebocx-init.sh

echo $(date)": This is the boot script" >/dev/kmsg
echo $(date)": Doing the needful"
bootscript=$(get_script_loc boot)
if [ "$bootscript" ]; then
    echo Launching bootscript $bootscript
    sleep 5
    exec $bootscript
fi

echo "Could not find bootscript. Sleeping and failing"
sleep 5
exit 255
