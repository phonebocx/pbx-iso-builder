#!/bin/bash

. /usr/local/bin/phonebocx-init.sh

ttyscript=$(get_script_loc $THISTTY)
if [ "$ttyscript" ]; then
    echo Launching $ttyscript
    sleep 5
    exec $ttyscript
fi

echo "/usr/local/bin/phonebocx.sh running on $THISTTY"
echo "There is no bootfile for this tty"
sleep infinity
