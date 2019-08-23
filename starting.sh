#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

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
      if (( $blocks == $lc )); then
        echo "[$1] Synced on block: $lc"
        return 1
      fi
    done
    if (( blocks == 0 )) && (( lc == 0 )); then
      # this chain is just not syncing even though it has network connections we will stop its deamon and abort for now. Myabe next time it will work.
      komodo-cli -ac_name=$chain stop
      echo -e "\033[1;31m  [$1] ABORTING no blocks or longest chain found, Help Human! \033[0m"
      return 0
    elif (( blocks == 0 )) && (( lc != 0 )); then
      # This chain has connections and knows longest chain, but will not sync, we will kill it. Maybe next time it will work.
      echo -e "\033[1;31m [$1] ABORTING - No blocks synced of $lc. Help Human! \033[0m"
      komodo-cli -ac_name=$chain stop
      return 0
    elif (( blocks > 128 )) && (( lc == 0 )); then
      # This chain is syncing but does not have longest chain. Likey it is just stalled. Start anyway.
      echo -e "\033[1;31m [$1] Synced to $blocks, but no longest chain is found. Starting anyway.\033[0m"
      return 1
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

checkSuperNETRepo () {
    if [ -z $1 ]; then
      return
    fi
    prevdir=${PWD}
    if [[ ! -f iguana/$1/lastbuildcommit ]]; then
      eval cd "$HOME/SuperNET"
      git pull > /dev/null 2>&1
      git checkout $1 > /dev/null 2>&1
      localrev=$(git rev-parse HEAD)
      mkdir -p $HOME/StakedNotary/iguana/$1
      echo $localrev > $HOME/StakedNotary/iguana/$1/lastbuildcommit
      cd $prevdir
    fi
    localrev=$(cat iguana/$1/lastbuildcommit)
    eval cd "$HOME/SuperNET"
    git remote update > /dev/null 2>&1
    remoterev=$(git rev-parse origin/$1)
    cd $prevdir
    if [ $localrev != $remoterev ]; then
      return 1
    else
      return 0
    fi
}

daemon_stopped () {
  if [[ $1 = "KMD" ]]; then
    pidfile="$HOME/.komodo/komodod.pid"
  else
    pidfile="$HOME/.komodo/$1/komodod.pid"
  fi
  while [[ -f $pidfile ]]; do
    pid=$(cat $pidfile 2> /dev/null)
    outcome=$(ps -p $pid 2> /dev/null | grep komodod)
    outcome=$(echo $?)
    if [[ ${outcome} -eq 1 ]]; then
      rm $pidfile
    fi
    sleep 2
  done
}

#temporary
type screen>/dev/null 2>&1 || sudo apt-get install screen

pubkey=$(./printkey.py pub)
Radd=$(./printkey.py Radd)
privkey=$(./printkey.py wif)

if [[ ${#pubkey} != 66 ]]; then
  echo -e "\033[1;31m ABORTING!!! pubkey invalid: Please check your config.ini \033[0m"
  exit 1
fi

if [[ ${#Radd} != 34 ]]; then
  echo -e "\033[1;31m [$1] ABORTING!!! R-address invalid: Please check your config.ini \033[0m"
  exit 1
fi

if [[ ${#privkey} != 52 ]]; then
  echo -e "\033[1;31m [$1] ABORTING!!! WIF-key invalid: Please check your config.ini \033[0m"
  exit 1
fi

ac_json=$(cat assetchains.json)
echo $ac_json | jq .[] > /dev/null 2>&1
outcome=$(echo $?)
if [[ $outcome != 0 ]]; then
  echo -e "\033[1;31m ABORTING!!! assetchains.json is invalid, Help Human! \033[0m"
  exit 1
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
  daemon_stopped "KMD"
  echo "[KMD] Stopped."
elif [[ $result = "update_failed" ]]; then
  echo -e "\033[1;31m [$branch] ABORTING!!! failed to update please build manually using ~/komodo/zcutil/build.sh to see what problem is! Help Human! \033[0m"
  exit 1
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
      daemon_stopped "${updated_chain}"
      echo "[$updated_chain] Stopped."
    elif [[ $result = "update_failed" ]]; then
      echo -e "\033[1;31m [$branch] ABORTING!!! failed to update please build manually using ~/komodo/zcutil/build.sh to see what problem is! Help Human! \033[0m"
      exit 1
    else
      echo "[$branch] No update required"
    fi
  elif [[ $master_updated = 1 ]]; then
    updated_chain=$(echo "${ac_json}" | jq  -r .[$i].ac_name)
    echo "[$updated_chain] Stopping ..."
    komodo-cli -ac_name=$updated_chain stop > /dev/null 2>&1
    daemon_stopped "${updated_chain}"
    echo "[$updated_chain] Stopped."
  fi
  i=$(( $i +1 ))
done

# Start KMD
echo "[KMD] : Starting KMD"
screen -S "KMD" -d -m $HOME/StakedNotary/komodo/master/komodod -stakednotary=1 -pubkey=$pubkey &

# Start assets
if [[ $(./assetchains "" ${@}) = "finished" ]]; then
  echo "Started Assetchains"
else
  echo -e "\033[1;31m Starting Assetchains Failed: help human! \033[0m"
  exit 1
fi

# Here we will extract all iguanas in assetchains.json and update them if needed
./listlizards.py | while read branch; do
    checkSuperNETRepo "${branch}"
    outcome=$(echo $?)
    if [[ ${outcome} -eq 1 ]]; then
      rm iguana/${branch}/iguana
    fi
    if [[ ! -f iguana/${branch}/iguana ]]; then
      echo "[${branch}] Building iguana...."
      ./build_iguana ${branch}
      if [[ -f iguana/${branch}/iguana ]]; then
          eval cd "$HOME/SuperNET"
          localrev=$(git rev-parse HEAD)
          echo $localrev > $HOME/StakedNotary/iguana/${branch}/lastbuildcommit
          cd $HOME/StakedNotary
          kill -15 $(pgrep -af "iguana ${branch}.json" | grep -v "$0" | grep -v "SCREEN" | awk '{print $1}')
      fi
    else
        echo "[${branch}] Iguana has no update.... "
    fi
done

# Validate Address on KMD + AC, will poll deamon until started then check if address is imported, if not import it.
echo "[KMD] : Waiting for KMD daemon to start..."
./validateaddress.sh KMD
validateaddress=$(komodo-cli validateaddress $Radd 2> /dev/null)
outcome=$(echo $?)
if [[ ${outcome} -eq 1 ]]; then
  echo -e "\033[1;31m Starting KMD Failed: help human! \033[0m"
  exit 1
fi

abort=0
./listassetchains.py | while read chain; do
  # Move our auto generated coins file to the iguana coins dir
  chmod +x "$chain"_7776
  mv "$chain"_7776 iguana/coins
  echo "[$chain] : Waiting for $chain daemon to start..."
  ./validateaddress.sh $chain
  cat restart_queue 2> /dev/null | while read restart_chain; do
    if [[ $restart_chain == $chain ]]; then
      ./asset-cli $chain stop
      daemon_stopped $chain
      if [[ $(./assetchains $chain ${@}) = "finished" ]]; then
        echo "[$chain] : Waiting for $chain daemon to restart..."
        ./validateaddress.sh $chain
        echo "Restarted $chain with blocknotify in conf"
      else
        echo -e "\033[1;31m Starting $chain with blocknotify in conf failed: help human! \033[0m"
        exit 1
      fi
    fi
  done
  validateaddress=$(komodo-cli -ac_name=$chain validateaddress $Radd 2> /dev/null)
  outcome=$(echo $?)
  if [[ ${outcome} -eq 1 ]]; then
    echo -e "\033[1;31m Starting $chain Failed: help human! \033[0m"
    echo "abort=1" > abort
  fi
done

source abort 2> /dev/null 
rm abort 2> /dev/null
if [[ $abort -eq 1 ]]; then
  rm restart_queue > /dev/null 2>&1
  exit 1
fi

echo "Checking chains are in sync..."

abort=0
checksync KMD
outcome=$(echo $?)
if [[ $outcome = 0 ]]; then
  abort=1
fi

#for row in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
#  checksync $row
#  outcome=$(echo $?)
#  if [[ $outcome = 0 ]]; then
#    abort=1
#  fi
#done

iguanajson=$(cat staked.json | jq -c '.' )
newiguanajson=$(komodo/master/komodo-cli getiguanajson | jq -c '.')
if [ "$iguanajson" != "$newiguanajson" ]; then
    echo $newiguanajson > staked.json
    ./listlizards.py | while read branch; do
        echo "[$branch] Updated staked.json, restarting iguana..."
        kill -15 $(pgrep -af "iguana ${json}" | grep -v "$0" | grep -v "SCREEN" | awk '{print $1}') > /dev/null 2>&1
    done
    sleep 2
fi

if [[ $abort -eq 0 ]]; then
  echo -e "\033[1;32m ALL CHAINS SYNC'd Starting Iguana's if they need starting then adding new chains for dPoW... \033[0m"
else
  echo -e "\033[1;31m Something went wrong, please check error messages above requiring human help and manually rectify them before starting iguana! \033[0m"
  rm restart_queue > /dev/null 2>&1
  exit 1
fi

./listlizards.py | while read branch; do
    ./start_iguana.sh ${branch}
done
