#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
curdir=$(pwd)

# Coin we're resetting
# e.g "KMD"
coin=$1

# Full daemon comand with arguments
# e.g "komodod -notary -pubkey=<pubkey>"
deamon=$2

# Daemon process regex to grep processes while we're waiting for it to exit
# e.g "komodod.*\-notary"
daemon_process_regex=$3

# Path to daemon cli
# e.g "komodo-cli"
cli=$4

# Path to wallet.dat
# e.g "${HOME}/.komodo/wallet.dat"
wallet_file=$5

# Address containing all your funds
# e.g "RPxsaGNqTKzPnbm5q7QXwu7b6EZWuLxJG3"
address=$6

date=$(date +%Y-%m-%d:%H:%M:%S)

echo "[${coin}] Resetting ${coin} wallet - ${date}"

waitforconfirm () {
  confirmations=0
  while [[ ${confirmations} -lt 1 ]]; do
    sleep 1
    confirmations=$(${cli} gettransaction $1 2> /dev/null | jq -r .confirmations) > /dev/null 2>&1
    # Keep re-broadcasting
    ${cli} sendrawtransaction $(${cli} getrawtransaction $1 2> /dev/null) > /dev/null 2>&1
  done
}

echo "[${coin}] Saving the main address privkey to reimport later"
privkey=$(${cli} dumpprivkey ${address})
echo "[${coin}] Main address: ${address}"
echo "[${coin}] Main privkey: ${privkey}"

# This is a placeholder, you can change it, but ti does not matter, its an empty address.
temp_privkey="SKxpMSzkNVnJynN7AeWG6f4nxNxfW3aA4xBez6e7KPMLruStj7yk"

# Get the block height before he process starts, we scan from here to include these 2 transactions.
HEIGHT=$(${cli} getblockcount)
echo "[${coin}] Current block count: $HEIGHT"

# Send the entire balance to ourself
txid=$(${cli} sendtoaddress ${address} $(${cli} getbalance) "" true)
if [[ ${#txid} != 64 ]]; then
  echo "[${coin}] Sending the balance to ourself failed: ABORT"
  # We should add some new logic here to keep sending in chuncks if for some reaons the wallet is too many utxo (or use z_mergetoaddress)
  exit
fi
waitforconfirm $txid
echo "[${coin}] Balance sent TXID: ${txid}"

echo "[${coin}] Stopping the deamon"
${cli} stop

stopped=0
while [[ ${stopped} -eq 0 ]]; do
  pgrep -af "${daemon_process_regex}" | grep -v "$0" > /dev/null 2>&1
  outcome=$(echo $?)
  if [[ ${outcome} -ne 0 ]]; then
    stopped=1
  fi
  sleep 2
done

echo "[${coin}] Backing up and removing wallet file"
mv "${wallet_file}" "${wallet_file}.${date}.bak"

echo "[${coin}] Restarting the daemon"
${deamon} > /dev/null 2>&1 &

started=0
while [[ ${started} -eq 0 ]]; do
  sleep 1
  ${cli} getbalance > /dev/null 2>&1
  outcome=$(echo $?)
  if [[ ${outcome} -eq 0 ]]; then
    started=1
  fi
done

echo "[${coin}] Importing the main privkey but without rescanning"
${cli} importprivkey ${privkey} "" false

echo "[${coin}] Importing the z_key and rescanning from $HEIGHT"
${cli} z_importkey ${temp_privkey} \"yes\" $HEIGHT

echo "[${coin}] Running UTXO splitter"
./utxosplitter.sh ${coin}

echo "[${coin}] Wallet reset complete!"
