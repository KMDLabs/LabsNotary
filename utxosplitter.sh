#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

# Optionally just split UTXOs for a single coin
# e.g "KMD"
specific_coin=$1

kmd_target_utxo_count=100
kmd_split_threshold=50

other_target_utxo_count=25
other_split_threshold=15

date=$(date +%Y-%m-%d:%H:%M:%S)

calc() {
  awk "BEGIN { print "$*" }"
}

if [[ -z "${specific_coin}" ]]; then
  echo "----------------------------------------"
  echo "Splitting UTXOs - ${date}"
  echo "KMD target UTXO count: ${kmd_target_utxo_count}"
  echo "KMD split threshold: ${kmd_split_threshold}"
  echo "Other target UTXO count: ${other_target_utxo_count}"
  echo "Other split threshold: ${other_split_threshold}"
  echo "----------------------------------------"
fi

./listcoins.sh | while read coin; do
  if [[ -z "${specific_coin}" ]] || [[ "${specific_coin}" = "${coin}" ]]; then
    cli=$(./listclis.sh ${coin})

    if [[ "${coin}" = "KMD" ]]; then
      target_utxo_count=$kmd_target_utxo_count
      split_threshold=$kmd_split_threshold
    else
      target_utxo_count=$other_target_utxo_count
      split_threshold=$other_split_threshold
    fi

    satoshis=10000
    amount=$(calc $satoshis/100000000)
    listunspent=$(${cli} listunspent)
    if [[ "${listunspent}" = "" ]]; then
      echo "[$coin] Listuspent call failed aborting!"
    else
      utxo_count=$(echo ${listunspent} | jq -r '.[].amount' | grep ${amount} | wc -l)
      echo "[${coin}] Current UTXO count is ${utxo_count}"

      utxo_required=$(calc ${target_utxo_count}-${utxo_count})

      if [[ ${utxo_required} -gt ${split_threshold} ]]; then
        echo "[${coin}] Splitting ${utxo_required} extra UTXOs"
        json=$(./splitfunds.sh ${coin} ${utxo_required})
        txid=$(echo ${json} | jq -r '.txid')
        if [[ ${txid} != "null" ]]; then
          echo "[${coin}] Split TXID: ${txid}"
        else
          echo "[${coin}] Error: $(echo ${json} | jq -r '.error')"
        fi
      fi
    fi
  fi
done
