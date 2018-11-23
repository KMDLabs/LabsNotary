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
    if (( $tries > 60)); then
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
  lc=$(longestchain $1)
  if [[ $lc = "0" ]]; then
    connections=$(komodo-cli -ac_name=$chain getinfo | jq -r .connections)
    if [[ $connections = "0" ]]; then
      echo -e "\033[1;31m  [$1] ABORTING - $1 has no network connections, Help Human! \033[0m"
      komodo-cli -ac_name=$chain stop
      return 0
    else
      lc=$(longestchain $1)
    fi
  fi
  if [[ $lc = "0" ]]; then
    blocks=$(komodo-cli -ac_name=$chain getblockcount)
    tries=0
    while (( $blocks < 128 )) && (( $tries < 90 )); do
      echo "[$1] $blocks blocks"
      blocks=$(komodo-cli -ac_name=$chain getblockcount)
      tries=$(( $tries +1 ))
      lc=$(longestchain $1)
      if (( $blocks = $lc )); then
        echo "[$1] Synced on block: $lc"
        return 1
      fi
    done
    if (( blocks = 0 )) && (( lc = 0 )); then
      # this chain is just not syncing even though it has network connections we will stop its deamon and abort for now. Myabe next time it will work.
      komodo-cli -ac_name=$chain stop
      echo -e "\033[1;31m  [$1] ABORTING no blocks or longest chain found, Help Human! \033[0m"
      return 0
    elif (( blocks = 0 )) && (( lc != 0 )); then
      # This chain has connections and knows longest chain, but will not sync, we will kill it. Maybe next time it will work.
      echo -e "\033[1;31m [$1] ABORTING - No blocks synced of $lc. Help Human! \033[0m"
      komodo-cli -ac_name=$chain stop
      return 0
    elif (( blocks > 128 )) && (( lc = 0 )); then
      # This chain is syncing but does not have longest chain. Myabe next time the prcess runs it will work, so we will leave it running but not add it to iguana.
      echo -e "\033[1;31m [$1] ABORTING - Synced to $blocks, but no longest chain is found. Help Human! \033[0m"
      return 0
    fi
  fi
  blocks=$(komodo-cli -ac_name=$chain getblockcount)
  while (( $blocks < $lc )); do
    sleep 60
    lc=$(longestchain $1)
    blocks=$(komodo-cli -ac_name=$chain getblockcount)
    progress=$(echo "scale=3;$blocks/$lc" | bc -l)
    echo "[$1] $(echo $progress*100|bc)% $blocks of $lc"
  done
  echo "[$1] Synced on block: $lc"
  return 1
}

daemon_stopped () {
  stopped=0
  while [[ ${stopped} -eq 0 ]]; do
    pgrep -af "$1" > /dev/null 2>&1
    outcome=$(echo $?)
    if [[ ${outcome} -ne 0 ]]; then
      stopped=1
    fi
    sleep 2
  done
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
  echo -e "\033[1;31m [$1] ABORTING!!! R-address invalid: Please check your config.ini \033[0m"
  exit
fi

if [[ ${#privkey} != 52 ]]; then
  echo -e "\033[1;31m [$1] ABORTING!!! WIF-key invalid: Please check your config.ini \033[0m"
  exit
fi

ac_json=$(cat assetchains.json)
echo $ac_json | jq .[] > /dev/null 2>&1
outcome=$(echo $?)
if [[ $outcome != 0 ]]; then
  echo -e "\033[1;31m ABORTING!!! assetchains.json is invalid, Help Human! \033[0m"
  exit
fi

# Here we will update/add the master branch of StakedNotary/komodo StakedNotary/komodo/<branch>
# and stop komodo if it was updated
echo "[master] Checking for updates and building if required..."
result=$(./update_komodo.sh master)
if [[ $result = "updated" ]]; then
  echo "[master] Updated to latest"
  master_updated=1
  echo "[KMD] Stopping ..."
  komodo-cli stop > /dev/null 2>&1
  daemon_stopped "komodod.*\-notary"
  echo "[KMD] Stopped."
elif [[ $result = "update_failed" ]]; then
  echo -e "\033[1;31m [master] ABORTING!!! failed to update, Help Human! \033[0m"
  exit
else
  echo "[master] No update required"
fi

# Here we will extract all branches in assetchain.json and build them and move them to StakedNotary/komodo/<branch>
# and stop any staked chains that use master branch if it was updated
i=0
./listbranches.py | while read branch; do
  if [[ $branch != "master" ]]; then
    echo "[$branch] Checking for updates and building if required..."
    result=$(./update_komodo.sh $branch)
    if [[ $result = "updated" ]]; then
      echo "[$branch] Updated to latest"
      updated_chain=$(echo "${ac_json}" | jq  -r .[$i].ac_name)
      echo "[$updated_chain] Stopping ..."
      komodo-cli -ac_name=$updated_chain stop > /dev/null 2>&1
      daemon_stopped "komodod.*\-ac_name=${updated_chain}"
      echo "[$updated_chain] Stopped."
    elif [[ $result = "update_failed" ]]; then
      echo -e "\033[1;31m [$branch] ABORTING!!! failed to update, Help Human! \033[0m"
      exit
    else
      echo "[$branch] No update required"
    fi
  elif [[ $master_updated = 1 ]]; then
    updated_chain=$(echo "${ac_json}" | jq  -r .[$i].ac_name)
    echo "[$updated_chain] Stopping ..."
    komodo-cli -ac_name=$updated_chain stop > /dev/null 2>&1
    daemon_stopped "komodod.*\-ac_name=${updated_chain}"
    echo "[$updated_chain] Stopped."
  fi
  i=$(( $i +1 ))
done

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
varesult=$(./validateaddress.sh KMD)
if [[ $varesult = "not_started" ]]; then
  echo -e "\033[1;31m Starting KMD Failed: help human! \033[0m"
  exit
fi
echo "[KMD] : $varesult"

./listassetchains.py | while read chain; do
  # Move our auto generated coins file to the iguana coins dir
  chmod +x "$chain"_7776
  mv "$chain"_7776 iguana/coins
  varesult=$(./validateaddress.sh $chain)
  if [[ $varesult = "not_started" ]]; then
    echo -e "\033[1;31m Starting $chain Failed: help human! \033[0m"
    exit
  fi
  echo "[$chain] : $varesult"
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

for row in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
	checksync $row
  outcome=$(echo $?)
  if [[ $outcome = 0 ]]; then
    abort=1
  fi
done

iguanajson=$(cat staked.json | jq -c '.' )
newiguanajson=$(komodo/master/komodo-cli getiguanajson | jq -c '.')
if [ "$iguanajson" != "$newiguanajson" ]; then
    echo $newiguanajson > staked.json
    pkill -15 iguana
    sleep 2
fi 

if [[ $abort = 0 ]]; then
  echo -e "\033[1;32m ALL CHAINS SYNC'd Starting Iguana if it needs starting then adding new chains for dPoW... \033[0m"
else
  echo -e "\033[1;31m Something went wrong, please check error messages above requiring human help and manually rectify them before starting iguana! \033[0m"
  exit
fi

./start_iguana.sh
