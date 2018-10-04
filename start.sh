#!/bin/bash
longestchain () {
  chain=$1
  if [[ $chain == "KMD" ]]; then
    chain=""
  fi
  tries=0
  longestchain=0
  while [[ $longestchain -eq 0 ]]; do
    info=$(komodo-cli -ac_name=$chain getinfo)
    longestchain=$(echo ${info} | jq -r '.longestchain')
    tries=$(( $tries +1 ))
    if (( $tries > 240)); then
      echo "0"
      return 0
    fi
    sleep 1
  done
  echo $longestchain
}

checksync () {
  chain=$1
  if [[ $chain == "KMD" ]]; then
    chain=""
  fi
  lc=$(longestchain $chain)
  blocks=$(komodo-cli -ac_name=$chain getinfo | jq -r .blocks)
  while (( $blocks < $lc )); do
    sleep 30
    lc=$(longestchain $chain)
    blocks=$(komodo-cli -ac_name=$chain getinfo | jq -r .blocks)
    progress=$(echo "scale=3;$blocks/$lc" | bc -l)
    echo "[$1] $(echo $progress*100|bc)% $blocks of $lc"
  done
  echo "[$1] Synced on block: $lc"
}

cd /home/$USER/StakedNotary
git pull
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

cd ~/SuperNET
returnstr=$(git pull)
cd /home/$USER/StakedNotary
if [[ $returnstr = "Already up-to-date." ]]; then
  echo "No Iguana update detected"
else
  rm iguana/iguana
fi

if [[ ! -f iguana/iguana ]]; then
  echo "Building iguana"
  ./build_iguana
  pkill -15 iguana
fi

echo "Checking chains are in sync..."

checksync KMD

ac_json=$(cat assetchains.json)
for row in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
	checksync $row
done

echo "[ ALL CHAINS SYNC'd Starting Iguana if it needs starting then adding new chains for dPoW... ]"

./start_iguana.sh
