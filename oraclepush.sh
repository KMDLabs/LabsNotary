#!/bin/bash
#argument 1 is json file to convert
#arg 2 should be already existing oracle txid with data type S
#arg 3 is chain the oracle is on
txid=$2
chain=$3
(cat $1 | tr -d '\n' | tr -d ' ') > assets.hex
xxd -p assets.hex | tr -d '\n' > rawhex
hexraw=$(cat rawhex)
declen=$(($(cat rawhex | wc -c) / 2 ))
echo $declen
if [ $declen -le 4096 ]
then 
	hexlen=$(echo "0$(printf '%x\n' $declen)")
else
	hexlen=$(printf '%x\n' $declen)
fi
len=$(echo ${hexlen:2:2}${hexlen:0:2})
komodo-cli -ac_name=$chain oraclesdata $txid $len$hexraw
