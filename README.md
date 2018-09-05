# Staked Notary Control Scripts

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

Once this is done, you have all the required things to launch iguana, there are some coins files in `iguana/coins` and iguana binary has been built from the SuperNET repo in your home folder and copied to `iguana` folder. Also the `staked.json` file containing all the info for the Notary Network has been fetched from github.

To start your notary node and connect to the network simply run:
```shell
./start_iguana.sh
```
There is one thing that notary nodes depend on more than anything else and that is the UTXO's. Once iguana has started we need to run @LukeChilds excellent UTXO splitter.
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

## Alright's instructions
There is the file `staked.json` in this repo, the pubkeys and IP's of our selected notaries need to go in this file. If you change it everyone needs to update. The `minsigs` parameter is how many notaries a notarization requires. The number of IP's in this file must always be exactly 8 or iguana will crash, you can use some more than once if needed.

The file `start_iguana.sh` contains an area called `ADD NOTARY AREA` you need to add every notaries IP to this part, copy paste the curl call and change the IP. Its not great having to have everyones IP recorded in a central place, but the network seems to break otherwise, especially if they are changed at some point.

I have set the port to `9999` this is the only port that NEEDS to be open on the notary node's unless you want them to seed the assetchains aswell. I would advise having seperate seeds if possibe.

Of couse each pubkey will need some KMD and some of the AC being notarized. Make sure you send some, if they have UTXO splitter on cron, it will take car of everything, as soon as funds arrive the node will split and start notarizing.

I advise we also change the pubkey from the 4 I have for scaletest, we should have new ones. Iguana can use a WIF, I tested it. No need for a passphrase.

### Adding New Coins
This is the coolest part, super happy about it. Simply add the coins params to `assetchains.json` (make sure you have the `freq` param it is required!) and submit a PR and merge it. Then have ALL operators:
```shell
pkill -15 iguana
./start.sh
./start_iguana.sh
```
Make sure some funds have been sent and everything *should* just work. :D

NOTE: *freq is the frequency of notarizations anything less than 10 is unlikley to work without changes to iguana*

### Using some of the Scripts
To get a list of coins: `./listcoins.sh`

To issue commands to a coin: `asset-cli <COINS_NAME> <COMMAND>`

To issue commands to all assetchains: `assets-cli <COMMAND>`

To kill everything: `./stop.sh`

The install scripts come with the tools:

`htop`: To monitor system load

`slurm`: To monitor network load

`tmux`: To make panes, so you can run these tools and iguana console logs at he same time and detach/reattach when you login/out of the notary node. Google is your friend.
