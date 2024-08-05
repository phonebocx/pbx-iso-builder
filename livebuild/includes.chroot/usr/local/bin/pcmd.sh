#!/bin/bash

. /usr/local/bin/phonebocx-init.sh

echo "Looking for command '$2' in module '$1'"
scr=$(get_script_loc $1 $2)

echo "I found $scr"
