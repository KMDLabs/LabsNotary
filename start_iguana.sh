#!/bin/bash
# unlock any locked utxos before restarting
komodo-cli lockunspent true `komodo-cli listlockunspent | jq -c .` 
wget -qO staked https://raw.githubusercontent.com/blackjok3rtt/StakedNotary/master/staked.json
iguana/iguana staked & #> iguana.log 2> error.log  &
myip=`curl -s4 checkip.amazonaws.com`
sleep 4
curl --url "http://127.0.0.1:7776" --data "{\"agent\":\"SuperNET\",\"method\":\"myipaddr\",\"ipaddr\":\"$myip\"}"
sleep 3

# addnotary method
for i in `cat peer_ips.txt`
do
    echo "Adding notary: $i"
    curl -s --url "http://127.0.0.1:7776" \
        --data "{\"agent\":\"iguana\",\"method\":\"addnotary\",\"ipaddr\":\"$i\"}"
done

# external coins.
iguana/coins/kmd_7776

# Unlock wallet.
passphrase=$(./printkey.py wif)
curl -s --url "http://127.0.0.1:7776" --data "{\"method\":\"walletpassphrase\",\"params\":[\"$passphrase\", 9999999]}"

# addcoin method for assetchains
./listassetchains.py | while read chain; do
  coin="iguana/coins/$chain"_7776
  $coin
done

sleep 10

# call the dpowassets python script
./dpowassets.py
