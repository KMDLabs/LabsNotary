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
    elif [[ $outcome = 5 ]]; then
      clean=1
      echo "[$coin] Private Chain Requires Z-Address to be used!"
    else
      echo "[$coin] $(echo $result | jq -r .remainingUTXOs) utxo remaining"
    fi
  done
  echo "[$coin] Wallet Clean!"
done

