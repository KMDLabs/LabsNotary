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

After this we are ready to launch KMD and any chains that happen to be in `assetchains.json` and import our private keys to them all.

```shell
./start.sh
```
To keep an eye on komodods sync status run: `tail -f ~/.komodo/debug.log` This could take a while. 2-3H maybe longer.

Once this is done, you have all the required things to launch iguana, there are some coins files in `iguana/coins` and iguana binary has been built from the SuperNET repo in your home folder and copied to `iguana` folder. Also the `staked.json` file containing all the info for the Notary Network has been fetched from github.

To start your notary node and connect to the network simply run:
```shell
./start_iguana.sh
```
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

### Adding New Coins
This is the coolest part, super happy about it. Simply add the coins params to `assetchains.json` (make sure you have the `freq` param it is required!) and submit a PR and merge it. Then have ALL operators:
```shell
pkill -15 iguana
./start.sh
./start_iguana.sh
```
There is no need to stop any deamons at this point, if they are already running, they will not start again.

Make sure some funds have been sent and everything *should* just work. :D

### Using some of the Scripts
To get a list of coins: `./listcoins.sh`

To issue commands to a coin: `asset-cli <COINS_NAME> <COMMAND>`

To issue commands to all assetchains: `assets-cli <COMMAND>`

To kill everything: `./stop.sh`

The install scripts come with the tools:

`htop`: To monitor system load

`slurm`: To monitor network load

`tmux`: To make panes, so you can run these tools and iguana console logs at he same time and detach/reattach when you login/out of the notary node. Google is your friend.
