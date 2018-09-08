#!/bin/bash
wget -qO staked https://raw.githubusercontent.com/StakedChain/StakedNotary/master/staked.json
iguana/iguana staked & #> iguana.log 2> error.log  &
myip=`curl -s4 checkip.amazonaws.com`
sleep 4
curl --url "http://127.0.0.1:7776" --data "{\"agent\":\"SuperNET\",\"method\":\"myipaddr\",\"ipaddr\":\"$myip\"}"
sleep 3

#
#ADD NOTARY AREA
curl --url "http://127.0.0.1:7776" --data "{\"agent\":\"iguana\",\"method\":\"addnotary\",\"ipaddr\":\"45.63.3.143\"}"
curl --url "http://127.0.0.1:7776" --data "{\"agent\":\"iguana\",\"method\":\"addnotary\",\"ipaddr\":\"45.63.14.153\"}"
curl --url "http://127.0.0.1:7776" --data "{\"agent\":\"iguana\",\"method\":\"addnotary\",\"ipaddr\":\"149.28.237.202\"}"
curl --url "http://127.0.0.1:7776" --data "{\"agent\":\"iguana\",\"method\":\"addnotary\",\"ipaddr\":\"195.201.150.200\"}"
curl --url "http://127.0.0.1:7776" --data "{\"agent\":\"iguana\",\"method\":\"addnotary\",\"ipaddr\":\"63.209.33.34\"}"
curl --url "http://127.0.0.1:7776" --data "{\"agent\":\"iguana\",\"method\":\"addnotary\",\"ipaddr\":\"149.28.237.202\"}"

#ADD NOTARY AREA
#

# external coins.
iguana/coins/kmd_7776

# Unlock wallet.
passphrase=$(./printkey.py wif)
curl -s --url "http://127.0.0.1:7776" --data "{\"method\":\"walletpassphrase\",\"params\":[\"$passphrase\", 9999999]}"

# addcoin method for assetchains
for chain in `ls iguana/coins/*`
do
    $chain
done

sleep 10

# call the dpowassets python script
./dpowassets.py
