#!/bin/bash

# This makes sure nothing is messing up our fonts and ANSI parsing
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

. /usr/local/bin/phonebocx-init.sh

THISTTY=$(get_this_ttyname)
ttyscript=$(get_script_loc core $THISTTY)
if [ "$ttyscript" ]; then
    export SCRIPTDIR=$(dirname $ttyscript)
    cd $SCRIPTDIR
    echo Launching $ttyscript from $SCRIPTDIR
    sleep 1
    exec $ttyscript
fi

echo "/usr/local/bin/phonebocx.sh running on $THISTTY"
echo "There is no bootfile for this tty"
sleep infinity
