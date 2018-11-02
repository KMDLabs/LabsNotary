#!/bin/bash
# Fetch the keys
Radd=$(./printkey.py Radd)
privkey=$(./printkey.py wif)

if [[ $1 = "KMD" ]]; then
  chain="komodo-cli"
else
  chain="komodo-cli -ac_name=$1"
fi

# Wait for the deamon to actually start
started=0
while [[ ${started} -eq 0 ]]; do
  sleep 1
  validateaddress=$($chain validateaddress $Radd 2> /dev/null)
  outcome=$(echo $?)
  if [[ ${outcome} -eq 0 ]]; then
    started=1
  elif [[ ${outcome} -eq 1 ]]; then
    echo "not_started"
    exit
  fi
done

mine=$(echo $validateaddress | jq -r .ismine)
if [[ $mine = "false" ]]; then
  $chain importprivkey $privkey "" false
  getinfo=$($chain getinfo)
  lc=$(echo $getinfo | jq -r .longestchain)
  height=$(echo $getinfo | jq -r .blocks)
  diff=$(( longestchain - height ))
  scanto=$(( longestchain - 50000 ))
  if [[ $diff -le 50000 ]]; then
    zadd=$($chain z_getnewaddress)
    priv=$($chain z_exportkey)
    $chain z_importkey $priv \"yes\" $scanto > /dev/null
  fi
else
  echo $Radd
fi
