#!/bin/bash
# Fetch pubkey
pubkey=$(./printkey.py pub)

# Start KMD
echo "[KMD] : Starting KMD"
/home/$USER/staked_master/src/komodod -notary -pubkey=$pubkey > /dev/null 2>&1 &

# Start assets
if [[ $(./assetchains) = "finished" ]]; then
  echo "Started Assetchains"
else
  echo "Starting Assetchains Failed: help human!"
  exit
fi

# Validate Address on KMD + AC, will poll deamon until started then check if address is imported, if not import it.
echo "[KMD] : Checking your address and importing it if required."
echo "[KMD] : $(./validateaddress.sh KMD)"
./listassetchains.py | while read chain; do
  # Move our auto generated coins file to the iguana coins dir
  chmod +x "$chain"_7776
  mv "$chain"_7776 iguana/coins
  echo "[$chain] : $(./validateaddress.sh $chain)"
done
echo "Building Iguana"
./build_iguana

echo "Finished: Checking chains are in sync..."

let numchains=1
let count=0;
kmdinfo=$(echo $(komodo-cli getinfo))
kmd_blocks=$(echo ${kmdinfo} | jq -r '.blocks')
kmd_longestchain=$(echo ${kmdinfo} | jq -r '.longestchain')
if [[ $kmd_blocks == $kmd_longestchain ]]; then
	let count=count+1;
	echo "[Komodo chain syncronised on block ${kmd_blocks}]"
else
	echo "[Komodo chain not syncronised. On block ${kmd_blocks} of ${kmd_longestchain}]"
fi


ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
for row in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
	let numchains=numchains+1;
	chain=$(echo $row)
	info=$(echo $(komodo-cli -ac_name=${chain} getinfo))
	blocks=$(echo ${info} | jq -r '.blocks')
	longestchain=$(echo ${info} | jq -r '.longestchain')
	if [[ $blocks == $longestchain ]]; then
		let count=count+1;
		echo "[${chain} chain syncronised on block ${blocks}]"
	else
		echo "[${chain} chain not syncronised. On block ${kmd_blocks} of ${kmd_longestchain}]"
	fi
done

if [[ $count == $numchains ]]; then
	echo "[ ALL SYSTEMS GO! ${count} / ${numchains} chains sync'd ]"
	echo "Starting Iguana..."
	./start_iguana.sh
else
	echo "[ NOT ALL CHAINS IN SYNC (${count} / ${numchains}), ABORTING ]"
	echo "Please check ALL your chains are synced before running start_iguana.sh"
fi

