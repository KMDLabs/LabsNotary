#!/bin/bash
date=$(date +%Y-%m-%d:%H:%M:%S)

if [[ -z "$1" ]]; then
  echo "Specify a coin, fool2!"
  exit
fi

coin=$1
cli=$(./listclis.sh ${coin})
address=$(./printkey.py Radd)

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

# Send the entire balance to ourself
echo "[${coin}] Sending balance to ourself."
txid=$(${cli} sendtoaddress ${address} $(${cli} getbalance) "" "" true)
if [[ ${#txid} != 64 ]]; then
  echo "[${coin}] Sending the balance to ourself failed: ABORT"
  # We should add some new logic here to keep sending in chuncks if for some reaons the wallet is too many utxo (or use z_mergetoaddress)
  exit
fi

waitforconfirm ${txid}

echo "[${coin}] ${txid} confirmed, running wallet cleaner..."

${cli} cleanwallettransactions ${txid}

echo "[${coin}] Running UTXO splitter"
./utxosplitter.sh ${coin}

echo "[${coin}] Wallet reset complete!"
