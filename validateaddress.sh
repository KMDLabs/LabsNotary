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
  elif [[ ${outcome} -eq -1 ]]; then
    echo "not_started"
    exit
  fi
done

mine=$(echo $validateaddress | jq -r .ismine)
if [[ $mine = "false" ]]; then
  $chain importprivkey $privkey
else
  echo $Radd
fi
