# LABS Notary Control Scripts

#-------=== TO UPDATE FROM StakedNotary ===-------
```shell 
cd ~ 
mv StakedNotary StakedNotary.old 
git clone https://github.com/KMDLabs/LabsNotary.git 
cp ~/StakedNotary.old/config.ini ~/LabsNotary/
cd LabsNotary/install
you may need to remove ~/komodo due to disk space requirements 
./buildkomodo.sh
cd .. 
./start.sh
``` 
#-------=== TO UPDATE FROM StakedNotary ===-------


## Setting up your VPS
You need a new user, you cannot use `root`

For ubuntu 16.04 login as root and create a user: `adduser`

Add your user to sudo: `gpasswd -a <user> sudo`

Its reccomended to install an SSH key to this user. https://www.digitalocean.com/community/tutorials/how-to-set-up-ssh-keys--2

Logout of root and login to your user to continue installing the notary repo.

## Install instructions
```shell
cd ~
git clone https://github.com/KMDLabs/LabsNotary.git
cd LabsNotary
```

#### Install the relavent repos and dependancies 
You need to build our special repo of `komodo` thanks to @libbscott and nanomsg and SuperNET for iguana. Both these scripts cover all required deps on debian based distros.
 ```shell
cd install
./installSuperNET.sh
./buildkomodo.sh
./installnanomsg.sh
``` 

If you want/need the python stuff install these:
```shell
sudo apt-get install python3-dev python3 libgnutls28-dev libssl-dev python3-pip

pip3 install setuptools 
pip3 install wheel 
pip3 install base58 slick-bitcoinrpc requests python-bitcoinlib configparser
```

Now you need to copy the config file and edit it with our pubkey/Raddress and WIF key for KMD.

```shell
cd ~/LabsNotary
cp config_example.ini config.ini
nano config.ini
```

e.g ` btcpubkey = 02.....`

We also need to unblock the iguana port. To find this look in `assetchains.json` for iguana_port (default is below):
```shell
sudo ufw allow 8222
sudo ufw allow 22
sudo ufw enable
```
After this we are ready to launch KMD and any chains that happen to be in `assetchains.json` and import our private keys to them all.

```shell
./start.sh
```
To keep an eye on komodods sync status run: `tail -f ~/.komodo/debug.log` This could take a while. 5 to 10 hours.The sync progress is printed to the terminal you started `start.sh` at.

Once iguana has started we need to run a now heavily modified excellent UTXO splitter by @lukechilds
```shell
./utxosplitter.sh
```
You also will want to put this UTXO splitter on a cron job once an hour.
```shell
crontab -e
```
Enter this into the cron tab:
```
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin
33 * * * * /home/<your_username>/LabsNotary/utxosplitter.sh >> /home/<your_username>/utxo_split.log 2>&1
```

## Using features of LabsNotary komodod.
### Wallet filter 
Add as many address as you like to the filter, by default it is off and lets all tx though, by whitelisting an address it allows it to send you funds when the filter is active. The address in the filter are saved to a text file in the coin datadir and reloaded on daemon start. 
 
Specify address for whilelisting with either the command line param or conf file setting:

`-whitelistaddress=RTVti13NP4eeeZaCCmQxc2bnPdHxCJFP9x`

RPCS: 

    `addwhitelistaddress` address
    `removewhitelistaddress` address
    `setwalletfilter` true/false 
    `getwalletfilterstatus` 


### Wallet transaction cleaner
`cleanwallettransactions` <txid>

-> Provide a txid to delete all tx in the wallet except the tx specified. The walletreset.sh script does this all for you.

-> Running without a txid specified will clean all transaction history in the wallet older than the last unspent utxo. 

### dpowlistunspent RPC 
-> Special RPC for iguana, it caches and returns unspent utxos very quickly. Needing a lean wallet.dat is now thing of the past. 

### Adding New Coins
Add the chain params to `assetchains.json` (make sure you have the `freq` param it is required!)
```shell
./start.sh
```

Make sure some funds have been sent and everything *should* just work. :D

### Using some of the Scripts

To get a list of coins: `./listcoins.sh`

To issue commands to a coin: `asset-cli <COINS_NAME> <COMMAND>`

To issue commands to all assetchains: `assets-cli <COMMAND>`

To kill everything: `./stop.sh`

To HARD reset a coins wallet: `./walletreset.sh <coin>`

Hard reset will send the entire balance to yourself, then remove all transactions that are not this transaction from the wallet after it has been confirmed. 

To SOFT reset a KMDs wallet (works with ac by specifying -ac_name=): `komodo-cli cleanwallettransactions`

For stats you have multiple options:
    -> `stats.sh` based off webworker01's script 
    
    -> `py_scripts/stats.py` this uses getNotarisationsFromBlock RPC, thansk to smk762 and Alright. 
    
    -> `py_scripts/notarypay_stats.py` this tallys notarypay coinbase payments, works on ac_notarypay chains only. 
    
To list internal iguana information such as revcmask and bestmask use:
    `checkmasks <chain> or <maskhex>`

The install scripts come with the tools:

`htop`: To monitor system load

`slurm`: To monitor network load

`tmux`: To make panes, so you can run these tools and iguana console logs at he same time and detach/reattach when you login/out of the notary node.
 
    -> https://github.com/gpakosz/.tmux
    
    -> https://leanpub.com/the-tao-of-tmux/read
    
    -> https://hackernoon.com/a-gentle-introduction-to-tmux-8d784c404340
        
`screen`: used for daemons, and iguana if we run more than one, to attach a coin:
    `screen -r <coin>` 
    To attach an iguana:
    `screen -r <branch>`
