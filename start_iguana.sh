#!/bin/bash
branch="staked"
json="staked.json"
rpc=$(./printkey.py rpc)
# ./start_iguana blackjok3r
if [[ ! -z $1 || $1 != "staked" ]]; then
    branch=$1
    rpc=$(cat assetchains.json | jq -r --arg branch $branch '[.[] | select(.iguana == $branch)] | .[0].iguana_rpc')
    cat staked.json | jq --argjson rpc $rpc '. += {"rpc_port":$rpc}' >> "${branch}.json"
    json="${branch}.json"
fi
pgrep -af "iguana ${json}" | grep -v "$0" > /dev/null 2>&1
outcome=$(echo $?)
if [[ $outcome != 0 ]]; then
  echo "Starting iguana $json"
  # unlock any locked utxos before restarting, this doesnt really work, for restarting just 1 lizard of many, it will unlock the utxos used by the others also.
  # NEED FIX PLEASE? or offload this problem to daemon utxo cache?
  komodo-cli lockunspent true `komodo-cli listlockunspent | jq -c .`
  screen -S $json -d -m iguana/${branch}/iguana ${json} & #> iguana.log 2> error.log &
fi

myip=`curl -s4 checkip.amazonaws.com`
sleep 4
curl --url "http://127.0.0.1:$rpc" --data "{\"agent\":\"SuperNET\",\"method\":\"myipaddr\",\"ipaddr\":\"$myip\"}"
sleep 3

# addnotary method
for i in `cat peer_ips.txt`
do
    echo "Adding notary: $i"
    curl -s --url "http://127.0.0.1:$rpc" --data "{\"agent\":\"iguana\",\"method\":\"addnotary\",\"ipaddr\":\"$i\"}"
done

# add KMD 
if [[ ! -f iguana/coins/kmd_$rpc ]]; then
    cat iguana/coins/kmd_7776 | sed "s/:7776/:${rpc}/" > iguana/coins/kmd_$rpc
    chmod +x iguana/coins/kmd_$rpc
fi
iguana/coins/kmd_$rpc

# Unlock wallet.
passphrase=$(./printkey.py wif)
curl -s --url "http://127.0.0.1:$rpc" --data "{\"method\":\"walletpassphrase\",\"params\":[\"$passphrase\", 9999999]}"

# addcoin method for assetchains
./listassetchains.py ${branch} | while read chain; do
  coin="iguana/coins/$chain"_7776
  sed -i "s/:7776/:${rpc}/" $coin 
  $coin
done

sleep 10

# call the dpowassets python script
./dpowassets.py $branch
