#!/bin/bash
#orclid must be an existing S oracle with registered publisher
#sub must be a registered publisher
orclid=01c542e1c65724007b2a42d16d4b8a7b5d38acdc6e3be190f14f9afd1449a160
sub=03159df1aa62f6359aed850b27ce07e47e25c16ef7ea867f7dde1de26813db34d8
pubs=$(komodo-cli -ac_name=STAKEDB1 oraclesinfo $orclid | jq -r '.registered | .[] | .publisher')
pubsarray=(${pubs///n/ })
batons=$(komodo-cli -ac_name=STAKEDB1 oraclesinfo $orclid | jq -r '.registered | .[] | .batontxid')
batonarray=(${batons///n/ })
len=$(komodo-cli -ac_name=STAKEDB1 oraclesinfo $orclid | jq -r '[.registered | .[] | .publisher] | length')

for i in $(seq 0 $(( $len - 1 )))
do
if [ $sub = ${pubsarray[$i]} ]
then
komodo-cli -ac_name=STAKEDB1 oraclessamples $orclid ${batonarray[$i]} 1 | jq -r '.samples[0][0]' | jq . > $HOME/.komodo/assetchains.json
fi
done
echo $HOME/.komodo/assetchains.json
