#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

# ./start_iguana <branch> 
# eg, start LABS blackjok3r iguana branch
# ./start_iguana blackjok3r
# does not work for KMD notary!

# LABS notaries as default
branch="staked"
json="labs.json"
rpc=$(./printkey.py rpc)

if [[ ! -z ${1} ]] && [[ ${1} != ${branch} ]]; then
    ac_json=$(cat assetchains.json)
    branch=${1}
    rpc=$(jq -r --arg branch ${branch} '[.[] | select(.iguana == $branch)] | .[0].iguana_rpc' <<<"${ac_json}")
    p2pport=$(jq -r --arg branch ${branch} '[.[] | select(.iguana == $branch)] | .[0].iguana_port' <<<"${ac_json}")
    if [[ ${p2pport} != "null" ]] && [[ ${rpc} != "null" ]]; then
        cat labs.json | sed "s/\"port\":9333/\"port\":${p2pport}/" | jq --argjson rpc ${rpc} '. += {"rpc_port":$rpc}' > "${branch}.json"
        json="${branch}.json"
    else
        echo -e "\033[1;31m Failed building ${branch}.json \033[0m"
    fi
fi
pgrep -af "iguana ${json}" | grep -v "$0" | grep -v "SCREEN" > /dev/null 2>&1
outcome=$(echo $?)
if [[ $outcome != 0 ]]; then
    echo "Starting iguana ${json}"
    iguana/${branch}/iguana ${json} & #screen -S $json -d -m iguana/${branch}/iguana ${json} & #> iguana.log 2> error.log &
fi

myip=`curl -s4 checkip.amazonaws.com`
sleep 4
curl --url "http://127.0.0.1:${rpc}" --data "{\"agent\":\"SuperNET\",\"method\":\"myipaddr\",\"ipaddr\":\"${myip}\"}"
sleep 3

# addnotary method
for ip in $(cat peer_ips.txt); do
    echo "Adding notary: ${ip}"
    curl -s --url "http://127.0.0.1:${rpc}" --data "{\"agent\":\"iguana\",\"method\":\"addnotary\",\"ipaddr\":\"${ip}\"}"
done

# add KMD
if [[ ! -f iguana/coins/kmd_${rpc} ]]; then
    cat iguana/coins/kmd_7776 | sed "s/:7776/:${rpc}/" > iguana/coins/kmd_${rpc}
    chmod +x iguana/coins/kmd_${rpc}
fi
iguana/coins/kmd_${rpc}

# Unlock wallet.
passphrase=$(./printkey.py wif)
curl -s --url "http://127.0.0.1:${rpc}" --data "{\"method\":\"walletpassphrase\",\"params\":[\"${passphrase}\", 9999999]}"

# addcoin method for assetchains
while read -r chain; do
    coin="iguana/coins/${chain}"_7776
    sed -i "s/:7776/:${rpc}/" ${coin}
    ${coin}
done < <(./listassetchains.py ${branch})

sleep 3

# start dpow 
./dpowassets.py "${branch}"
