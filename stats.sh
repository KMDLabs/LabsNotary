#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
# this script uses the wallet DB, use the stats.py script in py_scripts folder to extract chain data directly. 

myscriptDir="$( cd "$(dirname -- "$0")" ; pwd -P )"
cd $myscriptDir

#Stats script for Komodo Notary Nodes
# credit to webworker01 for the script this is based on here: https://github.com/webworker01/nntools/blob/master/stats
#Requires jq v1.5+ and bitcoin-cli, komodo-cli, chips-cli and gamecredits-cli installed (e.g. symlinked to /usr/local/bin)

#==Options - Only Change These==

#Seconds in display loop, change to false if you don't want it to loop
sleepytime=false

#How many transactions back to scan for notarizations
txscanamount=777

#==End Options==

# Just to be sure printf doesn't reject with "invalid number" error because of decimal separator
LC_NUMERIC="en_US.UTF-8"

timeSince () {
    local currentimestamp=$(date +%s)
    local timecompare=$1

    if [ ! -z $timecompare ] && [[ $timecompare != "null" ]]
    then
        local t=$((currentimestamp-timecompare))

        local d=$((t/60/60/24))
        local h=$((t/60/60%24))
        local m=$((t/60%60))
        local s=$((t%60))

        if [[ $d > 0 ]]; then
            echo -n "${d}d"
        fi
        if [[ $h > 0 ]]; then
            echo -n "${h}h"
        fi
        if [[ $d = 0 && $m > 0 ]]; then
            echo -n "${m}m"
        fi
        if [[ $d = 0 && $h = 0 && $m = 0 ]]; then
            echo -n "${s}s"
        fi

    fi
}

#Do not change below for any reason!
#The BTC and KMD address here must remain the same. Do not need to enter yours!
utxoamt=0.00010000
ntrzdamt=-0.00083600
kmdntrzaddr=RXL3YXG2ceaB6C5hfJcN4fvmLH2C34knhA
# timefilter can be used to ignore all notarizations before this time. set to end of LABS season1 as default. 
timefilter2=1572523200 

#format="%-13s %6s %6s %7s %12.4f %6s %6s %6s"

format="%-13s %12.4f %7s %7s %7s %7s %7s %7s %7s %7s %7s"

outputstats ()
{
    count=0
    totalntrzd=0
    now=$(date +"%H:%M")
    ac_json=$(cat assetchains.json)

    printf "\n\n"

    printf "%-13s %12s %7s %7s %7s %7s %7s %7s %7s %7s %7s\n" "-ASSET-" "-BALANCE-" "-TXN-" "-UTXO-" "-DUST-" "-NOTR-" "-BLOX-" "-PCT-" "-LAST-" "-CNCT-";

    # this will work with BTC based 3rd party coins by adding them to listclis.sh
    ./listclis.sh | while read cli; do
            info=$(${cli} getinfo)
            coin=$(jq -r .name <<<"${info}")
            freq=$(jq -r --arg coin ${coin} '.[] | select (.ac_name == $coin) | .freq' <<<"${ac_json}")
            # fetch your NN pubkey to use the following jq filter (thanks DeckerSU) to count utxos that iguana can actually use.
            # [.[] | select (.generated==false and .amount==0.0001 and .spendable==true and (.scriptPubKey == "'$NN_PUBKEY'"))]
            NN_PUBKEY="21$(jq -r .pubkey <<<"${info}")ac"
            if [[ "${NN_PUBKEY}" == "21ac" ]]; then
                NN_PUBKEY="21$(./printkey.py pub)ac"
            fi
            blocks=$(jq -r .blocks <<<"${info}")
            txinfo=$(${cli} listtransactions "" ${txscanamount})
            unspents=$(${cli} listunspent)
            lastntrztime=$(jq -r --arg address "${kmdntrzaddr}" '[.[] | select(.address==$address)] | sort_by(.time) | last | "\(.time)"' <<<"${txinfo}")
            ntrzd=$(jq --arg address "${kmdntrzaddr}" --arg timefilter ${timefilter2} '[.[] | select(.time>=($timefilter|tonumber) and .address==$address and .category=="send")] | length' <<<"${txinfo}")
            totalntrzd=$(( totalntrzd + ntrzd ))
            # this now shows the % of possible notarizations in the range of blocks scanned, was innaccurate before as the entire chain is not scanned. 
			if [[ "${coin}" = "KMD" ]]; then
				printpct=""
			else
				pct=$(echo "${ntrzd}/(${txscanamount}/${freq})*100" | bc -l)
				printpct="$(printf "%2.1f" $(echo ${pct}))%"
			fi
            printf "${format}" "${coin}" \
                "$(printf "%12.4f" $(jq .balance <<<"${info}"))" \
                "$(${cli} getwalletinfo | jq .txcount)" \
                "$(jq --arg amt "${utxoamt}" '[.[] | select (.generated==false and .amount==($amt|tonumber) and .spendable==true and (.scriptPubKey == "'$NN_PUBKEY'"))] | length' <<<"${unspents}")" \
                "$(jq --arg amt "${utxoamt}" '[.[] | select(.amount<($amt|tonumber))] | length' <<<"${unspents}")" \
                "${ntrzd}" \
                "${blocks}" \
                "${printpct}" \
                "$(timeSince ${lastntrztime})" \
                "$(jq .connections <<<"${info}")" 
                echo ""
    done
}

outputstats
