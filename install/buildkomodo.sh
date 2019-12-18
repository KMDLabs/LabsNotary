#!/bin/bash
#Install Deps
sudo apt-get update
sudo apt-get -y install build-essential pkg-config libc6-dev m4 g++-multilib autoconf libtool ncurses-dev unzip git python python-zmq zlib1g-dev wget libcurl4-openssl-dev bsdmainutils automake curl python3 python3-requests libsodium-dev
#Install Komodo
cd ${HOME}/LabsNotary
git clone https://github.com/KMDLabs/komodo.git LABSKomodo
cd LABSKomodo
./zcutil/fetch-params.sh
./zcutil/build.sh -j$(nproc)
mkdir -p $HOME/LabsNotary/komodo/master
localrev=$(git rev-parse HEAD)
echo $localrev > $HOME/LabsNotary/komodo/master/lastbuildcommit
mv src/komodod $HOME/LabsNotary/komodo/master
mv src/komodo-cli $HOME/LabsNotary/komodo/master
cd ~
mkdir .komodo
cd .komodo
touch komodo.conf
rpcuser=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)
rpcpassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)
echo "rpcuser=$rpcuser" > komodo.conf
echo "rpcpassword=$rpcpassword" >> komodo.conf
echo "server=1" >> komodo.conf
echo "txindex=1" >> komodo.conf
chmod 0600 komodo.conf
sudo ln -sf /home/$USER/LabsNotary/komodo/master/komodo-cli /usr/local/bin/komodo-cli
sudo ln -sf /home/$USER/LabsNotary/komodo/master/komodod /usr/local/bin/komodod
sudo ln -sf /home/$USER/LabsNotary/assets-cli /usr/local/bin/assets-cli
sudo ln -sf /home/$USER/LabsNotary/asset-cli /usr/local/bin/asset-cli
