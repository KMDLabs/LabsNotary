#!/bin/bash
#
# You MUST have jq installed for this to work https://stedolan.github.io/jq/download/
#
# use like: ./Consolidate.sh SUPERNET RJ8q5vbzEiSRNeAu39xYfawuTa9djYEsQK
#
# Thanks Genie for the merge script :) 
# https://raw.githubusercontent.com/TheComputerGenie/Misc_Stuff/master/Wallet%20stuff/Consolidate.sh

cd "${BASH_SOURCE%/*}" || exit
date=$(date +%Y-%m-%d:%H:%M:%S)

RESET="\033[0m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"

if [[ -z "$1" ]]; then
    echo "Specify a chain, fool!2"
    exit
fi

chain=$1
cli=$(./listclis.sh ${chain})
Addy=$(./printkey.py Radd)

echo "[${chain}] Resetting ${chain} wallet - ${date}"

# Send the entire balance to ourself with genies script, it will merge any number of utxo given enough time :D 
enabled="y"
maxInc="800" MinCheck="1" RawOut="[" OutAmount="0"
maxconf=$(${cli} getblockcount) maxconf=$((maxconf + 1))
txids=() vouts=() amounts=()
SECONDS=0
echo "Finding UTXOS in $maxconf blocks to consolidate ..."
unspents=$(${cli} listunspent $MinCheck $maxconf)
inputUTXOs=$(jq -cr '[map(select(.spendable == true)) | .[] | {txid, vout, amount}]' <<<"${unspents}")
UTXOcount=$(jq -r '.|length' <<<"${inputUTXOs}")
duration=$SECONDS
if (( $UTXOcount == 0 )); then 
    echo "zero UTXOs found... try again later... "
    exit 1
fi
echo "Found $UTXOcount UTXOs.... $(($duration % 60)) seconds"

function makeRaw() {
    for ((tc = 0; tc <= $1 - 1; tc++)); do
        RawOut2="{\"txid\":\"${txids[tc]}\",\"vout\":${vouts[tc]}},"
        RawOut="$RawOut$RawOut2"
        OutAmount=$(echo "scale=8; ($OutAmount + ${amounts[tc]})" | bc)
    done
    OutAmount=$(echo "scale=8; $OutAmount - 0.00001" | bc) OutAmount=${OutAmount/#./0.}
    RawOut="${RawOut::-1}" RawOut=$RawOut"] {\"$Addy\":$OutAmount}"
}
function addnlocktime() {
    nlocktime=$(printf "%08x" $(date +%s) | dd conv=swab 2>/dev/null | rev)
    chophex=$(echo $toSign | sed 's/.\{38\}$//')
    nExpiryHeight=$(echo $toSign | grep -o '.\{30\}$')
    newhex=$chophex$nlocktime$nExpiryHeight
}

LoopsCount=$(echo "scale=0; ($UTXOcount / $maxInc)" | bc)
echo "This will take $LoopsCount transaction(s) to complete...."
SECONDS=0
for txid in $(jq -r '.[].txid' <<<"${inputUTXOs}"); do txids+=("$txid"); done
duration=$SECONDS
echo "Captured txids... $(($duration % 60)) seconds"
SECONDS=0
for vout in $(jq -r '.[].vout' <<<"${inputUTXOs}"); do vouts+=("$vout"); done
duration=$SECONDS
echo "Captured vouts... $(($duration % 60)) seconds"
SECONDS=0
for amount in $(jq -r '.[].amount' <<<"${inputUTXOs}"); do
    if [[ "$amount" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        amounts+=("$amount")
    else
        amounts+=("$(printf "%.8f" $amount)")
    fi
done
duration=$SECONDS
echo "Captured amounts... $(($duration % 60)) seconds"
echo "Packed and ready to begin...."
for ((tlc = 0; tlc <= $LoopsCount; tlc++)); do
    echo "${#vouts[@]} UTXOs left to consolitate..."
    SECONDS=0
    if [[ ${#vouts[@]} -ge $maxInc ]]; then
        makeRaw $maxInc
    else
        makeRaw ${#vouts[@]}
    fi
    duration=$SECONDS
    echo "Created raw consolidated tx $(($duration % 60)) seconds"
    #echo $RawOut
    SECONDS=0
    toSign=$(${cli} createrawtransaction $RawOut)
    addnlocktime
    Signed=$(${cli} signrawtransaction $newhex | jq -r '.hex')
    lasttx=$(echo -e "$Signed" | ${cli} -stdin sendrawtransaction)
    echo "Consolidated $(jq '. | length' <<<"${RawOut}") UTXOs:"
    duration=$SECONDS
    echo "Sent signed raw consolidated tx: $lasttx for $OutAmount $ac_name  $(($duration % 60)) seconds"
    txids=("${txids[@]:$maxInc}")
    vouts=("${vouts[@]:$maxInc}")
    amounts=("${amounts[@]:$maxInc}")
    RawOut="[" OutAmount="0"
    sleep 10
done

# sort confirmed and unconfirmed and wait until all tx are confirmed before clearing wallet.dat of tx history.
declare -a unconfirmed=() confirmed=() tmpunconf=()
let i=0
while (( 1 == 1 )); do
    tmpunconf=()
    if (( i == 0 )); then
        tmpunconf="${txids[@]}"
    elif (( ${#unconfirmed[@]} > 0 )); then
        tmpunconf="${unconfirmed[@]}"
        unconfirmed=()
    else 
        break
    fi
    for txid in ${tmpunconf[@]}; do
        rawtx=$(${cli} getrawtransaction "${txid}" 1 2> /dev/null )
        confs=$(jq -r .confirmations <<<"${rawtx}")
        if (( confs == 0 )); then
            unconfirmed+="${txid}"
            if (( RANDOM % 33  == 0 )); then
                echo "rebroadcast: $(${cli} sendrawtransaction ${rawtx})"
            fi
        else 
            confirmed+="${txid}"
            echo "[${chain}] txid: ${txid} confs: ${confs}"
        fi
        sleep 1
    done
    echo "[${chain}] Confirmed txns: ${#confirmed[@]} Unconfirmed txns: ${#unconfirmed[@]}"
    ((++i))
done

echo "[${chain}] All our txns are confirmed, running wallet cleaner RPC to wipe transaction history..."

${cli} cleanwallettransactions

echo "[${chain}] Start breaking it all over again..."
./utxosplitter.sh ${chain}

echo "[${chain}] wallet fixed!"
