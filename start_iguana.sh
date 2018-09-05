#!/bin/bash
wget -qO staked https://raw.githubusercontent.com/StakedChain/StakedNotary/master/staked.json
iguana/iguana staked_nosplit & #> iguana.log 2> error.log  &
myip=`curl -s4 checkip.amazonaws.com`
sleep 4
curl --url "http://127.0.0.1:7776" --data "{\"agent\":\"SuperNET\",\"method\":\"myipaddr\",\"ipaddr\":\"$myip\"}"
sleep 3

#
#ADD NOTARY AREA
curl --url "http://127.0.0.1:7776" --data "{\"agent\":\"iguana\",\"method\":\"addnotary\",\"ipaddr\":\"145.239.204.33\"}"
#ADD NOTARY AREA
#

# external coins.
iguana/coins/btc_7776
iguana/coins/kmd_7776

# Unlock wallet.
passphrase=$(./printkey.py wif)
curl --url "http://127.0.0.1:7778" --data "{\"agent\":\"bitcoinrpc\",\"method\":\"encryptwallet\",\"passphrase\":\"$passphrase\"}" > /dev/null
curl --url "http://127.0.0.1:7776" --data "{\"method\":\"walletpassphrase\",\"params\":[\"$passphrase\", 9999999]}"

# Loop through assetchains.json and build the path to the approptiate coins file and run it.
./listassetchains.py | while read chain; do
  coin="iguana/coins/$chain"_7776
  $coin
done

sleep 10

# call the dpowassets python script
./dpowassets.py
