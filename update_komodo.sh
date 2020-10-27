#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
attempt=0
outcome=0

checkRepo () {
    if [ -z ${1} ]; then
        return
    fi
    prevdir=${PWD}
    if [[ ! -f komodo/${1}/lastbuildcommit ]]; then
        eval cd "${HOME}/LabsNotary/KomodoPlatform"
        git pull > /dev/null 2>&1
        git checkout ${1} > /dev/null 2>&1
        localrev=$(git rev-parse HEAD)
        mkdir -p ${HOME}/LabsNotary/komodo/${1}
        echo ${localrev} > ${HOME}/LabsNotary/komodo/${1}/lastbuildcommit
        cd ${prevdir}
    fi
    localrev=$(cat komodo/${1}/lastbuildcommit)
    eval cd "${HOME}/LabsNotary/KomodoPlatform"
    git remote update > /dev/null 2>&1
    remoterev=$(git rev-parse origin/${1})
    cd "${prevdir}"
    if [ "${localrev}" == "${remoterev}" ]; then
        return 0
    else
        return 1
    fi
}

buildkomodo () {
    cd ${HOME}/LabsNotary/KomodoPlatform
    loop=${2}
    rm -f ${HOME}/LabsNotary/KomodoPlatform/src/komodod ${HOME}/LabsNotary/KomodoPlatform/src/komodo-cli > /dev/null 2>&1
    if (( loop == 0 )); then
        make clean  > /dev/null 2>&1
        git pull > /dev/null 2>&1
        git checkout ${1} > /dev/null 2>&1
        git pull > /dev/null 2>&1
        ./zcutil/build.sh -j$(nproc) > /dev/null 2>&1
    else
        make -j$(nproc) > /dev/null 2>&1
    fi
    if [[ ! -f ${HOME}/LabsNotary/KomodoPlatform/src/komodod ]]; then
        return 1
    fi
    if [[ ! -f ${HOME}/LabsNotary/KomodoPlatform/src/komodo-cli ]]; then
        return 1
    fi
    localrev=$(git rev-parse HEAD)
    mkdir -p ${HOME}/LabsNotary/komodo/${1}
    echo ${localrev} > ${HOME}/LabsNotary/komodo/${1}/lastbuildcommit
    mv src/komodod ${HOME}/LabsNotary/komodo/${1}/
    mv src/komodo-cli ${HOME}/LabsNotary/komodo/${1}/
    return 0
}

if [[ -z ${1} ]]; then
    exit
fi

branch=${1}
attempt=${2}
outcome=1

if (( attempt == 0 )); then 
    checkRepo "${branch}"
    outcome=$(echo $?)
fi

if (( outcome != 0 )) || [[ ! -f komodo/${branch}/komodod ]] || [[ ! -f komodo/${branch}/komodo-cli ]]; then
    buildkomodo "${branch}" "${attempt}"
    echo $?
else 
    echo 2
fi
