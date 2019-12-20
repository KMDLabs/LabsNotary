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
mkdir -p ${HOME}/LabsNotary/komodo/master
localrev=$(git rev-parse HEAD)
echo ${localrev} > ${HOME}/LabsNotary/komodo/master/lastbuildcommit
mv src/komodod ${HOME}/LabsNotary/komodo/master
mv src/komodo-cli ${HOME}/LabsNotary/komodo/master
mkdir -p ${HOME}/.komodo
cd ${HOME}/.komodo
if [[ ! -f komodo.conf ]]; then 
    touch komodo.conf
    rpcuser=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)
    rpcpassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)
    # only rpcuser/rpcpassword are actually required
    echo "rpcuser=${rpcuser}" > komodo.conf
    echo "rpcpassword=${rpcpassword}" >> komodo.conf
    # echo "listen=0" >> komodo.conf
    # listen=0 will stop your daemon advertising its IP address, set this if you do not open chain p2p ports in firewall. 
    # echo "rpcallowip=127.0.0.1" >> komodo.conf
    # this is default set to localhost, and not reccomended to open to another IP, because the rpcuser/pass are sent unencrypted. 
    # PLEASE!!! use an ssh tunnel to map the remote port on server to a local port. 
    #   ssh -Cfo ExitOnForwardFailure=yes -NL <localport>:localhost:<remoteport> <ip_address_of_daemon>
    #   eg for KMD to a daemon at IP 178.124.73.37, mapping to deafult rpc port on local machine: 
    #       `ssh -Cfo ExitOnForwardFailure=yes -NL 7771:localhost:7771 178.124.73.37`
    chmod 0600 komodo.conf
fi
sudo ln -sf /home/${USER}/LabsNotary/komodo/master/komodo-cli /usr/local/bin/komodo-cli
sudo ln -sf /home/${USER}/LabsNotary/komodo/master/komodod /usr/local/bin/komodod
sudo ln -sf /home/${USER}/LabsNotary/assets-cli /usr/local/bin/assets-cli
sudo ln -sf /home/${USER}/LabsNotary/asset-cli /usr/local/bin/asset-cli
