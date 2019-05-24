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
  sleep 5
  validateaddress=$($chain validateaddress $Radd 2> /dev/null)
  outcome=$(echo $?)
  if [[ ${outcome} -eq 0 ]]; then
    started=1
  elif [[ ${outcome} -eq 1 ]]; then
    exit
  fi
done

mine=$(echo $validateaddress | jq -r .ismine)
if [[ $mine = "false" ]]; then
  echo "[$1] : Importing Private Key..... May take a very long time."
  echo -n "[$1] : "
  height=$($chain getblockcount)
  if [[ $height -lt 10000 ]]; then 
    $chain importprivkey $privkey 
  else
    $chain importprivkey $privkey "" true $(( $height - 10000 ))
  fi
else
  echo "[$1] : $Radd"
fi
