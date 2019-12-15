#!/bin/bash
# ./start.sh <NOTARY> <extra chain params> 
# all params optional, defaults to LABS notary
# eg to start LABS notary and reindex all LABS assetchains 
# ./start.sh LABS -reindex

cd "${BASH_SOURCE%/*}" || exit
git pull
if [[ ! -z ${1} ]]; then
    ./starting.sh "${@}"
fi
