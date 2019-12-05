#!/usr/bin/env python3
import re
import os
import sys
import json
import time
import platform
from slickrpc import Proxy
from os.path import expanduser
cwd = os.getcwd()
script_path = sys.path[0]
home = expanduser("~")

def def_creds(chain):
    rpcport =''
    coin_config_file = ''
    if chain == 'KMD':
        coin_config_file = str(home + '/komodo.conf')
    elif chain == 'BTC':
        coin_config_file = str(home + '/.bitcoin/bitcoin.conf')
    else:
        coin_config_file = str(home + '/.komodo/' + chain + '/' + chain + '.conf')
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
        elif chain == 'KMD':
            rpcport = 8333
        else:
            print("rpcport not in conf file, exiting")
            print("check "+coin_config_file)
            exit(1)
    return(Proxy("http://%s:%s@127.0.0.1:%d"%(rpcuser, rpcpassword, int(rpcport))))


nn_names =  {
                "0":"blackjok3r", "1":"Alright", "2":"webworker01",
                "3":"CrisF", "4":"smk762", "5":"jorian", "6":"TonyL",
                "7":"CHMEX", "8":"metaphilibert", "9":"gt", "10":"CMaurice",
                "11":"Bar_F1sh_Rel", "12":"zatJUM", "13":"dwy", "14":"gcharang",
                "15":"computergenie", "16":"daemonfox", "17":"SHossain", "18":"Nabob",
                "19":"mylo", "20":"PHBA2061", "21":"Exile13", 
             }

timestamp = int(time.time())
ignore_nodes = []
rpc = {}
with open('assetchains.json' ,'r') as f:
    labs_ac_data = json.loads(f.read())

labs_chains = []
for item in labs_ac_data:
    labs_chains.append(item['ac_name'])
    
for chain in labs_chains:
    rpc[chain] = def_creds(chain)
    notary_counts = {}
    ntx_blocks = 0
    blockheight = rpc[chain].getblockcount()
    start_at = blockheight - 1440
    if start_at < 0:
            start_at = 1
    for x in range(start_at, blockheight):
            resp = rpc[chain].getNotarisationsForBlock(x)
            for ac in resp['LABS']:
                    if ac['chain'] == chain:
                            ntx_blocks += 1
                            for notary in ac['notaries']:
                                    if notary not in ignore_nodes:
                                            if str(notary) not in notary_counts:
                                                    notary_counts.update({str(notary):0})
                                            count = notary_counts[str(notary)]+1
                                            notary_counts.update({str(notary):count})
#                            print("Block: "+str(x)+" | Txid: "+str(ac['txid'])+" | Hash: "+str(ac['blockhash']))
            time.sleep(0.01)

    print(chain+" notarisations in last 1440 blocks: "+str(ntx_blocks))
    for notary in sorted(notary_counts.keys()):
        if notary in nn_names:
            print(str(nn_names[notary])+": "+str(notary_counts[notary]))
        else:
            print("[NAME NOT FOUND]: "+str(notary_counts[notary]))
