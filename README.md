# Staked Notary Control Scripts

# Setting up your VPS
You need a new user, you cannot use `root`

For ubuntu 16.04 login as root and create a user: `adduser`

Add your user to sudo: `gpasswd -a <user> sudo`

Its reccomended to install an SSH key to this user. https://www.digitalocean.com/community/tutorials/how-to-set-up-ssh-keys--2

Logout of root and login to your user to continue installing the notary repo.

## Install instructions
```shell
cd ~
git clone https://github.com/StakedChain/StakedNotary.git
cd StakedNotary
```

You need to build our special repo of `komodo` thanks to @libbscott and nanomsg and SuperNET for iguana. Both these scripts cover all required deps on debian based distros.

```shell
cd install
./installSuperNET.sh
./buildkomodo.sh
./installnanomsg.sh
```

Now you need to copy the config file and edit it with our pubkey/Raddress and WIF key for KMD. There needs to be a space after the `=` sign on each line.

e.g ` btcpubkey = 02.....`

```shell
cd ..
cp config_example.ini config.ini
nano config.ini
```
We also need to unblock the iguana port. To find this:
```shell
sudo ufw allow 9997
sudo ufw allow 22
sudo ufw enable
```
There is a KMD bootstrap here if you want to use this first before starting it will save a lot of time, also some VPS providers seem to be skimmping on RAM, and will crash trying to sync KMD, in this case you need to use the bootstrap. Its not ideal, but it works. 

https://bootstrap.0x03.services/komodo/KMD.html

After this we are ready to launch KMD and any chains that happen to be in `assetchains.json` and import our private keys to them all.

```shell
./start.sh
```
To keep an eye on komodods sync status run: `tail -f ~/.komodo/debug.log` This could take a while. 2-3H maybe longer. Also the progress of sync is printed to the terminal you started `start.sh` from.

There is one thing that notary nodes depend on more than anything else and that is the UTXO's. Once iguana has started we need to run @lukechilds excellent UTXO splitter.
```shell
./utxosplitter.sh
```
You also will want to put this UTXO splitter on a cron job every 15 minutes.
```shell
crontab -e
```
Enter this into the cron tab:
```
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin
*/15 * * * * /home/<your_username>/StakedNotary/utxosplitter.sh >> /home/<your_username>/utxo_split.log 2>&1
```

## Using features of StakedNotary komodod.
### Wallet filter 
`-stakednotary=1` : This is pointless for staked chains, but needed for staked notary nodes on KMD to activate the filter, amoung other things.

`-mintxvalue=<amount in sats>`
This defualts to 1 coin (to make it lower on KMD to fund smaller amounts, set it to a lower amount of sats.
How it works:
-> Takes all the vouts in a transaction and counts which ones are to the notary nodes address (set with -pubkey=) 
-> Adds the value of these together (total in sats) 
-> Divides by the number of vouts, 
-> If the amount is less than this number the transacion is ignored, not added to wallet. This filter does not work with -rescan  so you can add them to wallet by doing a rescan if you need to.
-> If this number is 0, the wallet accetpts NO transactions, once a notary is funded, likely this should be the setting you use. Only allowing to send from yourself, for iguana utxo split txs. You should not set this to 0, if you need to fund your node. Likely setting this value to a low value on KMD is good idea.


`-whitelistaddress=RTVti13NP4eeeZaCCmQxc2bnPdHxCJFP9x`
-> No matter what the setting of the above setting is set to, this address can send you coins. You can use this to have a trusted address either from another notary, or a wallet owned by yourself to fund your node any amount at any time.

`cleanwallettransactions` RPC
-> Provide a txid to delete all tx in the wallet except the tx specified. The walletreset.sh script does this all for you.
-> Running without a txid specified will clean all transaction history in the wallet older than the last unspent utxo. 


### Adding New Coins
This is the coolest part, super happy about it. Simply add the coins params to `assetchains.json` (make sure you have the `freq` param it is required!) and submit a PR and merge it. Then have ALL operators:
```shell
./start.sh
```
There is no need to stop any deamons at this point, if they are already running, they will not start again.

Make sure some funds have been sent and everything *should* just work. :D

### Using some of the Scripts
To get a list of coins: `./listcoins.sh`

To issue commands to a coin: `asset-cli <COINS_NAME> <COMMAND>`

To issue commands to all assetchains: `assets-cli <COMMAND>`

To kill everything: `./stop.sh`

To HARD reset a coins wallet: `./walletreset.sh <coin>`

Hard reset will send the entire balance to yourself, then remove all transactions that are not this transaction from the wallet after it has been confirmed. Might look at changing this to after it has been notarised?

To SOFT reset a KMDs wallet (works with ac by specifying -ac_name=): `komodo-cli cleanwallettransactions`

Soft reset is generally what you will use. This mode, simply removes all txs from that wallet database that are all spent. It means you lose transaction history, but also keeps the node able to build txs in a speedy manner, very important for notarisaions. :) 

The install scripts come with the tools:

`htop`: To monitor system load

`slurm`: To monitor network load

`tmux`: To make panes, so you can run these tools and iguana console logs at he same time and detach/reattach when you login/out of the notary node. Google is your friend.
