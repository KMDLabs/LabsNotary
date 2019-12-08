#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

# ./stop.sh iguana_branch true
# ./stop.sh blackjok3r 1 // setting second param means stop iguana and all the chains its notarizing as well. 
# ./stop.sh kmd_branch 
# ./stop.sh master // stop all daemons on master branch. 
# ./stop.sh // kill everyone and everything

if [[ ! -z "${1}" ]]; then
    specific_iguana=$(./listlizards.py | uniq | grep ${1})
    specific_daemon=$(./listbranches.py | uniq | grep ${1})
    if [[ ${specific_iguana} != "" ]]; then
        echo "[iguana->${specific_iguana}] stopping..."
        kill -15 $(pgrep -af "iguana ${specific_iguana}.json" | grep -v "$0" | grep -v "SCREEN" | awk '{print $1}') > /dev/null 2>&1
        if [[ ! -z "${2}" ]]; then
            while read -r chain; do
                ./asset-cli ${chain} stop
            done < <(./listassetchains.py ${specific_iguana})
        fi
    fi
    if [[ ${specific_daemon} != "" ]]; then
        for chain in $(jq -r '[.[] | select(.branch == "'${specific_daemon}'")] | .[].ac_name' <"assetchains.json")
        do 
            ./asset-cli ${chain} stop
        done
    fi
else     
    # kill all iguanas 
    while read -r branch; do
        echo "[iguana->${branch}] stopping... "
        kill -15 $(pgrep -af "iguana ${branch}.json" | grep -v "$0" | grep -v "SCREEN" | awk '{print $1}') > /dev/null 2>&1
    done < <(./listlizards.py | uniq)
    # safley stop all daemons
    while read cli; do
        ${cli} stop 
    done < <(./listclis.sh)
fi
