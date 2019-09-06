#!/bin/bash
cd $HOME/StakedNotary/
addr=$(./printkey.py Radd)
./listassetchains.py | while read coin; do
  clean=0
  i=0
  echo "[$coin] Cleaning Wallet"
  while [[ $clean = 0 ]]; do
    result=$(komodo-cli -ac_name=$coin z_mergetoaddress '["ANY_TADDR"]' $addr 0.0001 0 0 1000000) # 2> /dev/null
    outcome=$(echo $?)
    if [[ $outcome = 6 ]]; then
      clean=1
    elif [[ $outcome = 0 ]]; then
      echo "[$coin] $(echo $result | jq -r .remainingUTXOs) utxo remaining"
  elif [[ $outcome = 1 ]] && (( i < 10 )); then
      echo "[$coin] Chain Syncing... waiting $i..."
      sleep 1
      i=$((i+1))
    else
      echo "[$coin] ABORTING $error happened!"
      clean=1
    fi
  done
  echo "[$coin] Wallet Clean!"
done
