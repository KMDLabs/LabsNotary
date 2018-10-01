#!/bin/bash
cd /home/$USER/StakedNotary
pubkey=$(./printkey.py pub)
nn_address=$(./printkey.py Radd)

# Coin we're resetting
coin=$1

daemon="komodod $(./listassetchainparams.py ${coin}) -pubkey=${pubkey}"
daemon_process_regex="komodod.*\-ac_name=${coin}"
cli="komodo-cli -ac_name=${coin}"
wallet_file="${HOME}/.komodo/${coin}/wallet.dat"

./walletreset.sh \
  "${coin}" \
  "${daemon}" \
  "${daemon_process_regex}" \
  "${cli}" \
  "${wallet_file}" \
  "${nn_address}"
