#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

# Optionally just split UTXOs for a single chain
# e.g "KMD"
specific_coin=$1

kmd_target_utxo_count=200
kmd_split_threshold=100

other_target_utxo_count=100
other_split_threshold=50

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

NN_PUBKEY="21$(./printkey.py pub)ac"

while read -r chain; do
    if [[ -z "${specific_coin}" ]] || [[ "${specific_coin}" = "${chain}" ]]; then
        cli=$(./listclis.sh ${chain})

        if [[ "${chain}" == "KMD" ]]; then
            target_utxo_count=${kmd_target_utxo_count}
            split_threshold=${kmd_split_threshold}
        else
            target_utxo_count=${other_target_utxo_count}
            split_threshold=${other_split_threshold}
        fi

        satoshis=10000
        amount=$(calc ${satoshis}/100000000)
        unspents=$(${cli} listunspent)
        numtotal=$(jq length <<<"${unspents}")
        if (( numtotal == 0 )); then
            echo "[${chain}] Listuspent call failed aborting!"
        else
            utxo_count=$(jq --arg amt "${amount}" '[.[] | select (.generated==false and .amount==($amt|tonumber) and .spendable==true and (.scriptPubKey == "'$NN_PUBKEY'"))] | length' <<<"${unspents}")
            echo "[${chain}] Current UTXO count is ${utxo_count}"
            utxo_required=$(calc ${target_utxo_count}-${utxo_count})

            if (( utxo_required > split_threshold )); then
                echo "[${chain}] Splitting ${utxo_required} extra UTXOs"
                json=$(./splitfunds.sh ${chain} ${utxo_required})
                txid=$(jq -r '.txid' <<<"${json}")
                if [[ ${txid} != "null" ]]; then
                    echo "[${chain}] Split TXID: ${txid}"
                else
                    printf "[${chain}] Error: $(jq -r '.error' <<<"${json}")\n Trying iguana splitfunds method.... \n"
                    branch=$(./listlizards.py ${chain})
                    iguana_rpc=$(cat assetchains.json | jq -r --arg branch ${branch} '[.[] | select(.iguana == $branch)] | .[0].iguana_rpc')
                    if [[ "${iguana_rpc}" == "null" ]] || [[ "${iguana_rpc}" == "" ]]; then 
                        iguana_rpc=$(./printkey.py rpc)
                    fi
                    curl "http://127.0.0.1:${iguana_rpc}" --silent --data "{\"chain\":\"${chain}\",\"agent\":\"iguana\",\"method\":\"splitfunds\",\"satoshis\":${utxo_size},\"sendflag\":1,\"duplicates\":${duplicates}}"
                fi
            fi
        fi
    fi
done < <(./listcoins.sh)
