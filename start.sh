#!/bin/bash
# Fetch pubkey
cd /home/$USER/StakedNotary
pubkey=$(./printkey.py pub)

# Start KMD
echo "[KMD] : Starting KMD"
komodod -notary -pubkey=$pubkey > /dev/null 2>&1 &

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

kmdinfo=$(echo $(komodo-cli getinfo))
kmd_blocks=$(echo ${kmdinfo} | jq -r '.blocks')
kmd_longestchain=$(echo ${kmdinfo} | jq -r '.longestchain')

# yet to test version checking - "longest chain can get lost quite easily on early chains, might need some extra check 
# @webworker01 has some code that checks explorers heights, which might be a good way to go, but we have to have explorers up first.
if [[ $kmd_longestchain == 0 ]]; then
        echo -e "\e[91m ** [Incompatible Komodo version. Join #staked on discord at https://discord.gg/tKRzWe to get latest version. ** \e[39m"
        exit 0;
fi

while [[ $kmd_blocks < $kmd_longestchain ]]; do
	kmd_progress=$(echo $kmd_blocks/$kmd_longestchain|bc)
	echo "[Komodo chain not syncronised. On block ${kmd_blocks} of ${kmd_longestchain}] $(echo $progress*100|bc)%"
        echo "will check again in 30 seconds"
	sleep 30
done
echo "[Komodo chain syncronised on block ${kmd_blocks}]"

ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
for row in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
	chain=$(echo $row)
	info=$(echo $(komodo-cli -ac_name=${chain} getinfo))
	blocks=$(echo ${info} | jq -r '.blocks')
	longestchain=$(echo ${info} | jq -r '.longestchain')

	while [[ $blocks < $longestchain ]]; do
		progress=$(echo blocks/longestchain|bc)
	        echo "[${chain} chain not syncronised. On block ${blocks} of ${longestchain}] $(echo $progress*100 | bc)%"
		echo "will check again in 30 seconds"
        	sleep 30
	done
	echo "[${chain} chain syncronised on block ${blocks}]"
done

echo "[ ALL CHAINS SYNC'd Starting Iguana... ]"
./start_iguana.sh
