#!/bin/bash
#set -eo pipefail
curdir=$(pwd)
cli=${pwd}komodo/master/komodo-cli

./listassetchains.py | while read chain; do
  if [[ $chain != "" ]]; then
    echo $chain
    port=$(${cli} -ac_name=$chain getinfo | jq .p2pport)
  fi
  if [[ $port != "" ]]; then
    sudo ufw allow $port comment "$chain"
  fi
done
