# Staked Notary Control Scripts

## Install instructions
```shell
cd ~
git clone https://github.com/StakedChain/StakedNotary.git
cd StakedNotary
```

You need to build our special repo of `komodo` thanks to @libbscott and nanomsg for iguana. Both these scripts cover all required deps on debian based distros.

```shell
cd install
./buildkomodo.sh
./installnanomsg.sh
```

Now you need to copy the config file and edit it with our pubkey/Raddress and WIF key for KMD.

```shell
cd ..
cp config_example.ini config.ini
nano config.ini
```

After this we are ready to launch KMD and any chains that happen to be in `assetchains.json`. If KMD is not already synced this will take many hours, I wold advise syncing KMD first to make the process a bit faster.
```shell
./start.sh
```

Once this is done, you have all the required things to launch iguana, there are some coins files in `iguana/coins` and iguana binary has been built from the SuperNET repo in your home folder and copied to `iguana` folder. Also the staked.json file containing all the info for the Notary Network has been fetched from github.

To start your notary node and connect to the network simply run:
```shell
./start_iguana.sh
```
There is one thing that notary nodes depend on more than anything else and that is the UTXO's. Once iguana has started we need to run the UTXO splitter.
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
*/15 * * * * /home/<your_username>/scripts/utxosplitter.sh >> /home/<your_username>/utxo_split.log 2>&1
```
