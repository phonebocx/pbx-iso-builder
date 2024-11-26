#!/bin/bash

. /usr/local/bin/phonebocx-init.sh

scr=$(get_script_loc $1 $2)

if [ "$scr" ]; then
    # Found something!
    cd $(dirname $scr)
    # We may have had a param...
    ./$(basename $scr) $3
else
    echo "Could not find command '$2' in module '$1'"
    exit 1
fi
