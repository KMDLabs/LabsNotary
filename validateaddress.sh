#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
Radd=$(./printkey.py Radd)
privkey=$(./printkey.py wif)
chain=${1}
cli=$(./listclis.sh ${chain})

# Wait for the deamon to actually start
started=0
while (( started == 0 )); do
    sleep 5
    validateaddress=$(${cli} validateaddress ${Radd} 2> /dev/null)
    outcome=$(echo $?)
    if (( outcome == 0 )); then
        started=1
    elif (( outcome == 1 )); then
        exit
    fi
done

mine=$(jq -r .ismine <<<"${validateaddress}")
if [[ ${mine} == "false" ]]; then
    echo "[${chain}] : Importing private key and rescanning last 10,000 blocks"
    height=$(${cli} getblockcount)
    if (( height < 10000 )); then 
        echo "[${chain}] : $(${cli} importprivkey ${privkey})"
    else
        echo "[${chain}] : $(${cli} importprivkey ${privkey} "" true $(( height - 10000 )))"
    fi
else
    echo "[${chain}] : ${Radd}"
fi
