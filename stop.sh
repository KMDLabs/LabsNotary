#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
if [[ ! -z $1 ]]; then
    echo "[$1] Stopping Iguana... "
    kill -15 $(pgrep -af "iguana ${1}.json" | awk '{print $1}') > /dev/null 2>&1
else 
    ./listlizards.py | while read branch; do
        echo "[$branch] Stopping Iguana... "
        kill -15 $(pgrep -af "iguana ${branch}.json" | awk '{print $1}') > /dev/null 2>&1
    done
    ./assets-cli stop
    komodo-cli stop
fi
