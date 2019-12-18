#!/usr/bin/env python3
import os
import re
import json
import http
import time
import platform
from slickrpc import Proxy

sweep_Radd = 'ENTER YOUR SWEEP ADDRESS HERE'
reserve = 5   # AMOUNT OF COINS TO KEEP IN WALLET

coins_json = os.getcwd()+'/assetchains.json'
operating_system = platform.system()

if operating_system == 'Darwin':
    ac_dir = os.environ['HOME'] + '/Library/Application Support/Komodo'
elif operating_system == 'Linux':
    ac_dir = os.environ['HOME'] + '/.komodo'
elif operating_system == 'Win64' or operating_system == 'Windows':
    ac_dir = '%s/komodo/' % os.environ['APPDATA']
    import readline

def def_creds(chain):
    rpcport ='';
    if chain == 'KMD':
        coin_config_file = str(ac_dir + '/komodo.conf')
    else:
        coin_config_file = str(ac_dir + '/' + chain + '/' + chain + '.conf')
    with open(coin_config_file, 'r') as f:
        for line in f:
            l = line.rstrip()
            if re.search('rpcuser', l):
                rpcuser = l.replace('rpcuser=', '')
            elif re.search('rpcpassword', l):
                rpcpassword = l.replace('rpcpassword=', '')
            elif re.search('rpcport', l):
                rpcport = l.replace('rpcport=', '')
    if len(rpcport) == 0:
        if chain == 'KMD':
            rpcport = 7771
        else:
            print("rpcport not in conf file, exiting")
            print("check "+coin_config_file)
            exit(1)
    return(Proxy("http://%s:%s@127.0.0.1:%d"%(rpcuser, rpcpassword, int(rpcport))))

def coins_info(coins_json_file, attrib='ac_name'):
        infolist = []
        with open(coins_json_file) as file:
            assetchains = json.load(file)
        for chain in assetchains:
            infolist.append(chain[attrib])
        return infolist

coins = coins_info(coins_json)
coins.append('KMD')
rpc = {}
for coin in coins:
	rpc[coin] = def_creds(coin)

for coin in coins:
	bal = rpc[coin].getbalance()
	if bal > reserve:
		amount = bal - reserve
		rpc[coin].sendtoaddress(sweep_Radd, amount)
		print(str(amount)+" "+coin+" sent to "+sweep_Radd)
	rpc[coin].cleanwallettransactions()
