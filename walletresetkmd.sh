#!/bin/bash
cd /home/$USER/StakedNotary
pubkey=$(./printkey.py pub)
nn_address=$(./printkey.py Radd)

coin="KMD"
deamon="komodod -notary -pubkey=$pubkey"
daemon_process_regex="komodod.*\-notary"
cli="komodo-cli"
wallet_file="${HOME}/.komodo/wallet.dat"

./walletreset.sh \
  "${coin}" \
  "${deamon}" \
  "${daemon_process_regex}" \
  "${cli}" \
  "${wallet_file}" \
  "${nn_address}"
