#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

branch()
{
    branch="master"
    attempt=$(jq -r --arg chain ${1} '.[] | select (.ac_name == $chain) | .branch' <"assetchains.json")
    if [[ ${attempt} != "null" ]] && [[ ${attempt} != "" ]]; then
        branch=${attempt}
    fi
    echo ${branch}
}

# Optionally just get the cli for a single coin
# e.g "KMD"

specfic_chain=${1}

# can add any 3rd party coins here also easily. 
if [[ -z "${specfic_chain}" ]] || [[ "${specfic_chain}" = "KMD" ]]; then
    echo "${HOME}/LabsNotary/komodo/master/komodo-cli"
fi

while read -r chain; do
    if [[ -z "${specfic_chain}" ]] || [[ "${specfic_chain}" == "${chain}" ]]; then
        echo "${HOME}/LabsNotary/komodo/$(branch ${chain})/komodo-cli -ac_name=${chain}"
    fi
done < <(./listassetchains.py)
