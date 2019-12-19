#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
# opens the p2p port for all assetchains in assetchains.json. NOTE: when a chain is removed, the rule is NOT automatically deleted. 
while read -r chain; do
    echo $chain
    port=$(${cli} -ac_name=$chain getinfo | jq -r .p2pport)
    if [[ "${port}" != "null" ]]; then
        sudo ufw allow "${port}" comment "${chain}"
    fi
done < <(./listassetchains.py)
