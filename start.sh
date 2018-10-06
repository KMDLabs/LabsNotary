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
    if (( $tries > 120)); then
      echo "0"
      return 0
    fi
    sleep 1
  done
  echo $longestchain
  return 1
}

checksync () {
  chain=$1
  if [[ $chain == "KMD" ]]; then
    chain=""
  fi
  lc=$(longestchain $chain)
  if [[ $lc = "0" ]]; then
    connections=$(komodo-cli -ac_name=$chain getinfo | jq -r .connections)
    if [[ $connections = "0" ]]; then
      echo "[$1] ABORTING - $1 has no network connections, Help Human!"
      return 0
    else
      lc=$(longestchain $chain)
    fi
  fi
  if [[ $lc = "0" ]]; then
    echo "[$1] You have ${connections} network connections but have returned longestchain 0 for 4 minutes. This chain my have forks or you may be on the wrong version of komodo. Help Human!"
    return 0
  fi
  blocks=$(komodo-cli -ac_name=$chain getinfo | jq -r .blocks)
  while (( $blocks < $lc )); do
    sleep 30
    lc=$(longestchain $chain)
    blocks=$(komodo-cli -ac_name=$chain getinfo | jq -r .blocks)
    progress=$(echo "scale=3;$blocks/$lc" | bc -l)
    echo "[$1] $(echo $progress*100|bc)% $blocks of $lc"
  done
  echo "[$1] Synced on block: $lc"
  return 1
}

cd /home/$USER/StakedNotary
git pull
pubkey=$(./printkey.py pub)
Radd=$(./printkey.py Radd)
privkey=$(./printkey.py wif)

if [[ ${#pubkey} != 66 ]]; then
  echo -e "\033[1;31m ABORTING!!! pubkey invalid: Please check your config.ini \033[0m"
  exit
fi

if [[ ${#Radd} != 34 ]]; then
  echo "\033[1;31m [$1] ABORTING!!! R-address invalid: Please check your config.ini \033[0m"
  exit
fi

if [[ ${#privkey} != 52 ]]; then
  echo "\033[1;31m [$1] ABORTING!!! WIF-key invalid: Please check your config.ini \033[0m"
  exit
fi

# Start KMD
echo "[KMD] : Starting KMD"
komodod -notary -pubkey=$pubkey > /dev/null 2>&1 &

# Start assets
if [[ $(./assetchains) = "finished" ]]; then
  echo "Started Assetchains"
else
  echo -e "\033[1;31m Starting Assetchains Failed: help human! \033[0m"
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

abort=0
checksync KMD
outcome=$(echo $?)
if [[ $outcome = 0 ]]; then
  abort=1
fi

ac_json=$(cat assetchains.json)
for row in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
	checksync $row
  outcome=$(echo $?)
  if [[ $outcome = 0 ]]; then
    abort=1
  fi
done

if [[ $abort = 0 ]]; then
  echo -e "\033[1;32m ALL CHAINS SYNC'd Starting Iguana if it needs starting then adding new chains for dPoW... \033[0m"
else
  echo -e "\033[1;31m Something went wrong, please check error messages above requiring human help and manually rectify them before starting iguana! \033[0m"
  exit
fi

./start_iguana.sh
