#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
# opens the p2p port for all assetchains in assetchains.json. NOTE: when a chain is removed, the rule is NOT automatically deleted. 
curdir=$(pwd)
cli=${pwd}komodo/master/komodo-cli

./listassetchains.py | while read chain; do
    if [[ $chain != "" ]]; then
        echo $chain
        port=$(${cli} -ac_name=$chain getinfo | jq .p2pport)
    fi
    if [[ $port != "" ]]; then
        sudo ufw allow $port comment "$chain"
    fi
done
