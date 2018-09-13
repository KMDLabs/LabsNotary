#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

coin=$1
duplicates=$2

curl http://127.0.0.1:7776 --silent --data "{\"coin\":\"${coin}\",\"agent\":\"iguana\",\"method\":\"splitfunds\",\"satoshis\":10000,\"sendflag\":1,\"duplicates\":${duplicates}}"
