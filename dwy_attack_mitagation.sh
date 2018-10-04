#!/bin/bash
addr=$(./printkey.py Radd)
./listassetchains.py | while read coin; do
  clean=0
  echo "[$coin] Cleaning Wallet"
  while [[ $clean = 0 ]]; do
    result=$(komodo-cli -ac_name=$coin z_mergetoaddress '["ANY_TADDR"]' $addr 0.0001 0 0 1 2> /dev/null)
    outcome=$(echo $?)
    if [[ $outcome = 6 ]]; then
      clean=1
    elif [[ $outcome = 0 ]]; then
      echo "[$coin] $(echo $result | jq -r .remainingUTXOs) utxo remaining"
    else
      echo "[$coin] Some error happened!"
    fi
  done
  echo "[$coin] Wallet Clean!"
done
