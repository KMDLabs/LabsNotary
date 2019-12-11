#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

RESET="\033[0m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"

override_args=""
notary_arg="-notary -gen -genproclimit=1"
# first param is the notary to start, LABS or KMD. 
if [[ ! -z "${1}" ]]; then
    notary="${1}"
    if [[ "${notary}" != "KMD" ]]; then 
        notary_arg="labsnotary=1"
    fi
    cp assetchains_${notary}.json assetchains.json > /dev/null 2>&1
    ac_json=$(cat assetchains.json)
    echo ${ac_json} | jq .[] > /dev/null 2>&1
    outcome=$(echo $?)
    if (( outcome != 0 )); then
        echo -e ${RED}"[${notary}] assetchains.json is invalid, check git blame and start flame war..."${RESET}
        exit 1
    fi
    override_args="${2} ${3} ${4} ${5} ${6} ${7} ${8} ${9} ${10}"
else 
    echo "./starting.sh NOTARY <extra chain params>"
    exit 1
fi

longestchain () {
    chain=$1
    cli=$(./listclis.sh ${chain})
    tries=0
    lc=0
    while (( lc == 0 )); do
        info=$(${cli} getinfo 2> /dev/null)
        lc=$(jq -r '.longestchain'<<<"${info}")
        tries=$(( tries +1 ))
        connections=$(jq -r .connections <<<"${info}")
        if (( tries > 10 )) && (( lc == 0 )) && (( connections > 1 )); then
            headers=$(${cli} getpeerinfo  2> /dev/null | jq -r '[sort_by(.synced_headers) | .[].synced_headers]')
            n=$(( $(jq length <<<"${headers}") -1 ))
            lc=$(jq -r .[${n}] <<<"${headers}")
        fi
        if (( tries > 30 )) && (( lc == 0 )); then
            echo "${lc}"
            return 1
        fi
        sleep 2
    done
    echo "${lc}"
    return 0
}

checksync () {
    chain=$1
    cli=$(./listclis.sh ${chain})
    lc=$(longestchain $1)
    blocks=$(${cli} getblockcount 2> /dev/null)
    while (( blocks < lc )); do
        sleep 60
        lc=$(longestchain ${chain})
        blocks=$(${cli} getblockcount 2> /dev/null)
        progress=$(echo "scale=3;${blocks}/${lc}" | bc -l)
        echo "[${chain}] $(echo ${progress}*100|bc)% ${blocks} of ${lc}"
        info=$(${cli} getnetworkinfo 2> /dev/null)
        connections=$(jq -r .connections <<<"${info}")
        if (( connections == 0 )); then 
            break 
        fi
    done
    echo "[${chain}] Synced on block: ${lc}"
    return 0
}

checkSuperNETRepo () {
    prevdir=${PWD}
    if [[ ! -f iguana/${1}/lastbuildcommit ]]; then
        eval cd "${HOME}/SuperNET"
        git pull > /dev/null 2>&1
        git checkout ${1} > /dev/null 2>&1
        localrev=$(git rev-parse HEAD)
        mkdir -p ${HOME}/LabsNotary/iguana/${1}
        echo ${localrev} > ${HOME}/LabsNotary/iguana/${1}/lastbuildcommit
        cd ${prevdir}
    fi
    localrev=$(cat iguana/${1}/lastbuildcommit)
    eval cd "${HOME}/SuperNET"
    git remote update > /dev/null 2>&1
    remoterev=$(git rev-parse origin/${1})
    cd ${prevdir}
    if [[ "${localrev}" != "${remoterev}" ]]; then
        return 0
    else
        return 1
    fi
}

stop_daemon() {
    chain=${1}
    echo "[kmd->${chain}] Stopping ..."
    cli=$(./listclis.sh ${chain})
    ${cli} stop > /dev/null 2>&1
    daemon_stopped "${chain}"
    echo "[kmd->${chain}] Stopped."
}

daemon_stopped () {
    if [[ ${1} == "KMD" ]]; then
        pidfile="${HOME}/.komodo/komodod.pid"
    else
        pidfile="${HOME}/.komodo/${1}/komodod.pid"
    fi
    while [[ -f ${pidfile} ]]; do
        pid=$(cat ${pidfile} 2> /dev/null)
        pspid=$(ps -p ${pid} 2> /dev/null | grep komodod)
        outcome=$(echo $?)
        echo -n "ps -p ${pid} grep komodod = ${pspid} "
        if (( outcome != 0 )); then
            rm ${pidfile}
        fi
        echo "${outcome}"
        sleep 2
    done
}

check_chain_started () {
    chain=${1}
    cli=$(./listclis.sh ${chain})
    echo "[${chain}] : Waiting for ${chain} daemon to start..."
    ./validateaddress.sh ${chain}
    ${cli} getblockcount > /dev/null 2>&1
    outcome=$(echo $?)
    if (( outcome == 1 )); then
        echo -e ${RED}"Starting ${chain} failed. fix it! "${RESET}
        exit 1
    fi
}

get_kmdbranch() {
    branch="master"
    attempt=$(jq -r --arg chain ${1} '.[] | select (.ac_name == $chain) | .branch' <<<"${ac_json}")
    if [[ ${attempt} != "null" ]] && [[ ${attempt} != "" ]]; then
        branch=${attempt}
    fi
    echo ${branch}
}

get_iguanabranch() {
    branch="blackjok3r"
    attempt=$(jq -r --arg chain ${1} '.[] | select (.ac_name == $chain) | .iguana' <<<"${ac_json}")
    if [[ ${attempt} != "null" ]] && [[ ${attempt} != "" ]]; then
        branch=${attempt}
    fi
    echo ${branch}
}

chain_start_cmd () {
    chain="${1}"
    branch=$(get_kmdbranch "${chain}")
    params="$(./listassetchainparams.py "${chain}")"
    echo ""${PWD}"/komodo/"${branch}"/komodod "${params}""
}

start_assetchain () {
    chain=${1}
    iguana=$(jq -r --arg chain "${chain}" '.[] | select (.ac_name == $chain) | .iguana' <<<"${ac_json}")
    rpc=$(jq -r --arg chain "${chain}" '.[] | select (.ac_name == $chain) | .iguana_rpc' <<<"${ac_json}")
    conf="${HOME}/.komodo/${chain}/${chain}.conf"
    if [[ "${iguana}" == "blackjok3r" ]];then 
        if [[ -f "${conf}" ]]; then
            sed -i '/blocknotify/d' "${conf}"
            echo "blocknotify=curl -s --url \"http://127.0.0.1:${rpc}\" --data \"{\\\"agent\\\":\\\"dpow\\\",\\\"method\\\":\\\"updatechaintip\\\",\\\"blockhash\\\":\\\"%s\\\",\\\"symbol\\\":\\\"${chain}\\\"}\"" >> ${conf}
        else
            echo "${chain}" >> restart_queue
        fi
    fi
    screen -S ${chain} -d -m $(chain_start_cmd ${chain}) -pubkey=${pubkey} ${override_args} &
}

pubkey=$(./printkey.py pub)
Radd=$(./printkey.py Radd)
privkey=$(./printkey.py wif)
rm restart_queue > /dev/null 2>&1

if [[ ${#pubkey} != 66 ]]; then
    echo -e ${RED}" Pubkey invalid: Please check your config.ini "${RESET}
    exit 1
fi

if [[ ${#Radd} != 34 ]]; then
    echo -e ${RED}" R-address invalid: Please check your config.ini "${RESET}
    exit 1
fi

if [[ ${#privkey} != 52 ]]; then
    echo -e ${RED}" WIF-key invalid: Please check your config.ini "${RESET}
    exit 1
fi

# update all branches that need updating
declare -a updated_branches=()
let n=0
while read -r branch; do
    echo "[kmd->${branch}] Checking for updates and building, could take years off your life..."
    # try 3 times before annoying the OP with an error ^^
    let ret=3
    for (( i = 0; i < 3; i++ )); do
        ret=$(./update_komodo.sh ${branch} ${i})
        if [[ "${ret}" == "2" ]]; then 
            echo "[kmd->${branch}] no update... "
            break 
        elif [[ "${ret}" == "0" ]]; then
            echo "[kmd->${branch}] Updated to $(cat komodo/${branch}/lastbuildcommit 2> /dev/null)"
            updated_branches+=("${branch}")
            break
        elif (( i == 3 )); then
            echo -e ${RED}"[kmd->${branch}] Failed to update 3 times! Build manually or fix the problem." ${RESET}"
                cd LABSKomodo 
                git checkout ${branch} 
                ./zcutil/build.sh -j""$(nproc)"
            exit 1
        else
            echo "[kmd->${branch}] retrying build $(( 3-i)) more times"
        fi
    done 
    let n=n+1
done < <(./listbranches.py | uniq)

wait_for_last_function () {
    waitfor=${1}
    for pid in ${waitfor[*]}; do
        wait ${pid}
    done
}

# stop all daemons that are using an updated branch, to restart them later. 
pids=()
while read -r chain; do
    if [[ ${updated_branches[*]} =~ $(get_kmdbranch ${chain}) ]]; then 
        stop_daemon "${chain}" &
        pids[${chain}]=$!
    fi
done < <(./listcoins.sh)
wait_for_last_function ${pids}

# Start KMD
sed -i '/daemon/d' "${HOME}/.komodo/komodo.conf" > /dev/null 2>&1
echo "[kmd->master] : Starting KMD"
screen -S "KMD" -d -m ${HOME}/LabsNotary/komodo/master/komodod ${notary_arg} -pubkey=${pubkey} &

# Start assetchains
while read -r chain; do
    start_assetchain ${chain} &
done < <(./listassetchains.py)

# We can add another start scipt for 3rd party coins here :) 

# extract all iguanas in assetchains.json and update them if needed
while read -r branch; do
    if $(checkSuperNETRepo "${branch}"); then
        rm iguana/${branch}/iguana 2> /dev/null
    fi
    if [[ ! -f iguana/${branch}/iguana ]]; then
        echo "[iguana->${branch}] building ...."
        ./build_iguana ${branch}
        if [[ -f iguana/${branch}/iguana ]]; then
            eval cd "${HOME}/SuperNET"
            localrev=$(git rev-parse HEAD)
            echo ${localrev} > ${HOME}/LabsNotary/iguana/${branch}/lastbuildcommit
            cd ${HOME}/LabsNotary
            if [[ ${notary} == "KMD" ]]; then
                json="elected.json"
            else 
                json="${branch}.json"
            fi
            kill -15 $(pgrep -af "iguana ${elected}" | grep -v "$0" | grep -v "SCREEN" | awk '{print $1}')
        fi
    else
        echo "[iguana->${branch}] no update"
    fi
done < <(./listlizards.py | uniq)

pids=()
while read -r chain; do
    # Move our auto generated coins file to the iguana coins dir
    # this file is not auto generated by non KMD daemons and must be created manually 
    if [[ "${chain}" != "KMD" ]] && [[ -f "${chain}"_7776 ]]; then 
        chmod +x "${chain}"_7776
        mv "${chain}"_7776 iguana/coins
    fi
    check_chain_started "${chain}" &
    pids[${chain}]=$!
    if [[ $(cat restart_queue 2> /dev/null | grep "${chain}") == "${chain}" ]]; then
        stop_daemon "${chain}"
        start_assetchain "${chain}" 
        echo "[${chain}] : Waiting for ${chain} daemon to restart with blocknotify added to conf..."
        check_chain_started "${chain}" &
        pids[${chain}]=$!
    fi
done < <(./listassetchains.py) # to add 3rd party coins use listcoins.sh 
wait_for_last_function ${pids}

pids=()
while read chain; do
    checksync "${chain}"
    pids[${chain}]=$!
done < <(./listcoins.sh)
wait_for_last_function ${pids}

if [[ ${notary} == "KMD" ]]; then
    json="elected.json"
else 
    iguanajson=$(jq -c '.' <labs.json)
    newiguanajson=$(komodo/master/komodo-cli getiguanajson | jq -c '.')
    if [[ "${iguanajson}" != "${newiguanajson}" ]]; then
        echo "${newiguanajson}" > labs.json
        while read -r branch; do
            echo "[iguana->${branch}] Updated elected notaries json, stopping iguana..."
            kill -15 $(pgrep -af "iguana ${branch}.json" | grep -v "$0" | grep -v "SCREEN" | awk '{print $1}') > /dev/null 2>&1
        done < <(./listlizards.py | uniq)
    fi
fi

echo -e ${GREEN}"All chains started sucessfully, party time... "${RESET}

while read -r branch; do    
    ./start_iguana.sh "${branch}"
done < <(./listlizards.py | uniq)
