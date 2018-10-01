#!/bin/bash
cd /home/$USER/StakedNotary
# Reset KMD
./walletresetkmd.sh &
# Loop all AC resets
./listassetchains.py | while read chain; do
   ./walletresetac.sh ${chain} &
done
