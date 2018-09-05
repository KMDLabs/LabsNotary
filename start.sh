#!/bin/bash
# Fetch pubkey
pubkey=$(./printkey.py pub)
passphrase=$(./printkey.py wif)
cp m_notary_blank m_notary_staked

# Start KMD
echo "[KMD] : Starting KMD"
komodod -notary -pubkey=$pubkey > /dev/null 2>&1 &

# Start assets
if [[ $(./assetchains) = "finished" ]]; then
  echo "Started Assetchains"
else
  echo "Starting Assetchains Failed: help human!"
  exit
fi

# Validate Address on KMD + AC, will poll deamon until started then check if address is imported, if not import it.
echo "[KMD] : Checking your address and importing it if required."
echo "[KMD] : $(./validateaddress.sh KMD)"
./listassetchains.py | while read chain; do
  # Move our auto generated coins file to the iguana coins dir
  chmod +x "$chain"_7776
  mv "$chain"_7776 iguana/coins
  cat iguana/coins/"$chain"_7776 >> m_notary_staked
  echo $'\n' >> m_notary_staked
  echo "[$chain] : $(./validateaddress.sh $chain)"
done

echo "passphrase=$passphrase" > /home/$USER/SuperNET/iguana/passphrase.txt
echo "sleep 3" >> m_notary_staked
echo "cd /home/$USER/StakedNotary" >> m_notary_staked
echo "./dpowassets.py" >> m_notary_staked
mv m_notary_staked /home/$USER/SuperNET/iguana/
cp wp_7776 /home/$USER/SuperNET/iguana/

echo "Building Iguana"
#./build_iguana
echo "pubkey=$pubkey" > /home/$USER/SuperNET/iguana/pubkey.txt
echo "Finished: Please check ALL your chains are synced before running start_iguana.sh"
